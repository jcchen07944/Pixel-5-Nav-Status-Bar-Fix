#!/sbin/busybox sh
# set perm system files

SYS=/system
APP=/system/app
PAPP=/system/priv-app
FRAP=/system/framework


chmod -R 644 $FRAP/framework-res.apk
chmod -R 644 $PAPP/SystemUIGoogle/SystemUIGoogle.apk


