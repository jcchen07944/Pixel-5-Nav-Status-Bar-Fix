SKIPMOUNT=false
PROPFILE=false
POSTFSDATA=false
LATESTARTSERVICE=false

REPLACE = "/system/framework/services.jar
"

print_modname() {
   ui_print "*******************************"
   ui_print "        TransientBar Fix       "
   ui_print "*******************************"
}

on_install() {
   ui_print "- Extracting module files"
   unzip -o "$ZIPFILE" 'system/*' -d $MODPATH >&2
}

set_permissions() {
  set_perm_recursive $MODPATH 0 0 0755 0644
}