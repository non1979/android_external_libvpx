# Rules to generate assembly.
# Input variables:
#   libvpx_2nd_arch
#   libvpx_source_dir
#   libvpx_config_dir_<arch>
#   libvpx_codec_srcs_asm_<arch>
#
# Output variables:
#   LOCAL_GENERATED_SOURCES_<arch>
#   LOCAL_C_INCLUDES_<arch>
#

# ARM and x86 use an 'offsets' file in the assembly. It is generated by
# tricking the compiler and generating non-functional output which is then
# processed with grep. For ARM, this must be additionally converted from
# RVCT (ARM's in-house compiler) format to GNU Assembler Format for gcc.

# Offset files are currently used in vpx_scale for NEON and some encoder
# functions used in both ARM and x86. These files can not be compiled and need
# to be named accordingly to avoid auto-build rules. The encoder files are not
# used yet but are included in the comments for future reference.

libvpx_asm_offsets_intermediates := \
    vp8/encoder/vp8_asm_enc_offsets.intermediate \
    vpx_scale/vpx_scale_asm_offsets.intermediate \

libvpx_asm_offsets_files := \
    vp8/encoder/vp8_asm_enc_offsets.asm \
    vpx_scale/vpx_scale_asm_offsets.asm \

libvpx_intermediates := $(call local-intermediates-dir,,$(libvpx_2nd_arch))
# Build the S files with inline assembly.
COMPILE_TO_S := $(addprefix $(libvpx_intermediates)/, $(libvpx_asm_offsets_intermediates))
$(COMPILE_TO_S) : PRIVATE_2ND_ARCH := $(libvpx_2nd_arch)
$(COMPILE_TO_S) : PRIVATE_INTERMEDIATES := $(libvpx_intermediates)
$(COMPILE_TO_S) : PRIVATE_SOURCE_DIR := $(libvpx_source_dir)
$(COMPILE_TO_S) : PRIVATE_CONFIG_DIR := $(libvpx_config_dir_$(TARGET_$(libvpx_2nd_arch)ARCH))
$(COMPILE_TO_S) : PRIVATE_CUSTOM_TOOL = $($(PRIVATE_2ND_ARCH)TARGET_CC) -S $(addprefix -I, $($(PRIVATE_2ND_ARCH)TARGET_C_INCLUDES)) -I $(PRIVATE_INTERMEDIATES) -I $(PRIVATE_SOURCE_DIR) -I $(PRIVATE_CONFIG_DIR) -DINLINE_ASM -o $@ $<
$(COMPILE_TO_S) : $(libvpx_intermediates)/%.intermediate : $(libvpx_source_dir)/%.c
	$(transform-generated-source)

# Extract the offsets from the inline assembly.
OFFSETS_GEN := $(addprefix $(libvpx_intermediates)/, $(libvpx_asm_offsets_files))
$(OFFSETS_GEN) : PRIVATE_OFFSET_PATTERN := '^[a-zA-Z0-9_]* EQU'
$(OFFSETS_GEN) : PRIVATE_SOURCE_DIR := $(libvpx_source_dir)
$(OFFSETS_GEN) : PRIVATE_CUSTOM_TOOL = grep $(PRIVATE_OFFSET_PATTERN) $< | tr -d '$$\#' | perl $(PRIVATE_SOURCE_DIR)/build/make/ads2gas.pl > $@
$(OFFSETS_GEN) : %.asm : %.intermediate
	$(transform-generated-source)

LOCAL_GENERATED_SOURCES_$(TARGET_$(libvpx_2nd_arch)ARCH) += $(OFFSETS_GEN)

ifneq ($(strip $(libvpx_codec_srcs_asm_$(TARGET_$(libvpx_2nd_arch)ARCH))),)
# This step is only required for ARM. MIPS uses intrinsics and x86 requires an
# assembler to pre-process its assembly files.
# The ARM assembly sources must be converted from ADS to GAS compatible format.
VPX_GEN := $(addprefix $(libvpx_intermediates)/, $(libvpx_codec_srcs_asm_$(TARGET_$(libvpx_2nd_arch)ARCH)))
$(VPX_GEN) : PRIVATE_SOURCE_DIR := $(libvpx_source_dir)
$(VPX_GEN) : PRIVATE_CUSTOM_TOOL = cat $< | perl $(PRIVATE_SOURCE_DIR)/build/make/ads2gas.pl > $@
$(VPX_GEN) : $(libvpx_intermediates)/%.s : $(libvpx_source_dir)/%
	$(transform-generated-source)

LOCAL_GENERATED_SOURCES_$(TARGET_$(libvpx_2nd_arch)ARCH) += $(VPX_GEN)
endif

LOCAL_C_INCLUDES_$(TARGET_$(libvpx_2nd_arch)ARCH) += \
    $(libvpx_intermediates)/vp8/common \
    $(libvpx_intermediates)/vp8/decoder \
    $(libvpx_intermediates)/vp8/encoder \
    $(libvpx_intermediates)/vpx_scale
