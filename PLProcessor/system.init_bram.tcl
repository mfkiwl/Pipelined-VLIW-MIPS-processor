cd C:/Users/torbjlan/dmkonsttdt4255_work/PLProcessor/system
if { [ catch { xload xmp system.xmp } result ] } {
  exit 10
}
if { [catch {run init_bram} result] } {
  exit -1
}
exit 0
