addon_name="MinimapClickToTarget"
rm $addon_name.zip
mkdir _zip
cp -r $addon_name _zip
cd _zip
find . -name "*.DS_Store" -type f -delete
zip -r $addon_name.zip $addon_name
mv $addon_name.zip ..
cd ..
rm -r _zip
