ui_print "~ Removing stock bloats..."

for app in rm -r Calculator Email Browser
do
  ui_print "~ Removing $app"
  rm -r /system/app/$app
done

