# dc_synth.tcl

# Convert the project directory to an absolute path, and set the paths for the
# source file directories
set project_dir [exec readlink -m $project_dir]
set student_src_dir $project_dir/src
set top_dir $project_dir/tests

if {![info exists clock_period]} {
    set clock_period 10.0
} elseif {![string is double $clock_period] || $clock_period <= 0} {
    puts -nonewline "Error: Clock period '$clock_period' is not a positive "
    puts "double value."
    exit 1
}

#-------------------------------------------------------------------------------
# Setup and Variables
#-------------------------------------------------------------------------------

set student_src [exec find -L $student_src_dir -type f -name "*.v" \
        -o -name "*.sv" | sort]
set top_src [exec readlink -m $top_dir/synth_top.sv]
set src [concat $top_src $student_src]

# Set the libraries used to implement the design
set target_library ../../NangateOpenCellLibrary_typical_ccs.db
set link_library   ../../NangateOpenCellLibrary_typical_ccs.db

# Setup the compiler for parallel compilation with the max number of threads.
set cores [exec getconf _NPROCESSORS_ONLN]
set threads [expr min($cores, 16)]
set_host_options -max_cores $threads

# Define a library where our synthesized design files will be stored
define_design_lib WORK -path "./work"

#-------------------------------------------------------------------------------
# Design Synthesis
#-------------------------------------------------------------------------------

# Syntax check the source files, and create library objects for the files for
# design synthesis.
if {![analyze -format sverilog -lib WORK $src]} {
    exit 1
}

# Synthesize the design into a technology-independent design, and link the
# design to library components and references to other modules in the design.
if {![elaborate $top_module -lib WORK]} {
    exit 1
}

# Even though the elaborate command already performs linking, it succeeds even
# if linking fails, so link is run again to check for this case.
if {![link]} {
    exit 1
}

#-------------------------------------------------------------------------------
# Design and Optimization Constraints
#-------------------------------------------------------------------------------

# Set the design to optimize as the top module. All modules in the hierarchy
# below will also be optimized.
current_design $top_module

# Create a clock for the design, and set its period. This can be changed to a
# lower value to force the synthesis tool to work harder to optimize the design.
create_clock -period $clock_period clk

# Model a semi-realistic delay for main memory by setting a delay on the input
# ports to the top module.
set real_inputs [remove_from_collection [all_inputs] clk]
set_input_delay -clock clk 0.0 $real_inputs
set_output_delay -clock clk 0.0 [all_outputs]

# Set the maximum allowed combinational delay to be the clock period.
set_max_delay $clock_period [all_outputs]

# For some reason, DC very heavily prefers using ripple-carry adders when
# implementing addition, even if the design isn't meeting timing. Thus, we force
# the compiler not to use them, so it will instead use carry-lookahead adders.
set_dont_use standard.sldb/DW01_addsub/rpl
set_dont_use standard.sldb/DW01_add/rpl
set_dont_use standard.sldb/DW01_sub/rpl

#-------------------------------------------------------------------------------
# Design Optimization
#-------------------------------------------------------------------------------

# Optimize the design. The effort options tell the compiler to fully optimize
# for area and timing. Boundary optimization allows the compiler to optimize
# between module boundaries. Incremental mapping makes the compiler
# incrementally improve the design by experimenting with different approaches.
# This also prevents the DC compiler from crashing, which it is prone to do if
# the timing constraints for the design are not met.
if {![compile -map_effort high -area_effort high -boundary_optimization \
        -incremental_mapping]} {
    exit 1
}

#-------------------------------------------------------------------------------
# Report Generation
#-------------------------------------------------------------------------------

# Check the final optimized design for any inconsistencies and report them.
if {![check_design]} {
    exit 1
}

# Report the area, timing, and power consumption of the design.
report_area -hierarchy > area.rpt
report_timing > timing.rpt
report_power -hierarchy > power.rpt
write -format verilog -output netlist.sv

exit 0
