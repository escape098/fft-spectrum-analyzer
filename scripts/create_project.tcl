# =========================================================
# Vivado project creation script (FINAL FIXED VERSION)
# Device : XC7A35T-CSG324-1
# =========================================================

# -------- locate project root safely --------
set script_dir [file dirname [info script]]
set proj_root  [file normalize "$script_dir/.."]
set build_dir  "$proj_root/build"

# -------- user params --------
set proj_name fft-spectrum-analyzer
set part_name xc7a35tcsg324-1
set top_name  top

puts "Script dir  : $script_dir"
puts "Project root: $proj_root"
puts "Build dir   : $build_dir"

# -------- create project --------
file mkdir $build_dir
create_project $proj_name $build_dir -part $part_name -force

set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# -------- RTL --------
set rtl_dir "$proj_root/rtl"
if {[file exists $rtl_dir]} {
    set rtl_files [glob -nocomplain -directory $rtl_dir *.v *.sv]
    if {[llength $rtl_files] > 0} {
        puts "Adding RTL files:"
        foreach f $rtl_files { puts "  $f" }
        add_files -norecurse $rtl_files
    }
}

# -------- Constraints --------
set xdc_dir "$proj_root/constraints"
if {[file exists $xdc_dir]} {
    set xdc_files [glob -nocomplain -directory $xdc_dir *.xdc]
    if {[llength $xdc_files] > 0} {
        puts "Adding XDC files:"
        foreach f $xdc_files { puts "  $f" }
        add_files -fileset constrs_1 $xdc_files
    }
}

# -------- IP (.xci) --------
set ip_dir "$proj_root/ip"
if {[file exists $ip_dir]} {
    set xci_list [glob -nocomplain -directory $ip_dir *.xci]
    foreach xci $xci_list {
        puts "Import IP: $xci"
        import_ip $xci
    }
}

# -------- top --------
set_property top_fft_fpga $top_name [current_fileset]

# -------- IP handling (safe) --------
update_ip_catalog
set ips [get_ips]
puts "Detected IPs: $ips"

if {[llength $ips] > 0} {
    upgrade_ip $ips
    generate_target all $ips
} else {
    puts "No IPs detected, skip IP generation"
}

puts "============================================="
puts " Vivado project created successfully!"
puts "============================================="
