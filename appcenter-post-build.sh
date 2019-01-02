set +x
WORK_DIR=`pwd`

echo "Creating an Android emulator..."
cd $ANDROID_HOME/tools/bin
echo "y" | ./sdkmanager "system-images;android-26;google_apis;arm64-v8a"
for i in {1..4};do echo "y"; done | ./sdkmanager --licenses
touch ~/.android/repositories.cfg

echo "no" | ./avdmanager create avd --force -n Nexus_5X_API_26 -k "system-images;android-26;google_apis;arm64-v8a"

echo "Starting the Android emulator..."

cd $ANDROID_HOME/emulator
nohup emulator -avd Nexus_5X_API_26 -no-snapshot > /dev/null 2>&1 &

echo "Wait for the Android emulator process started..."
i=1
while ! $ANDROID_HOME/platform-tools/adb devices |grep 'emulator-';do
   if [ $i -eq 10 ];then
    echo "No emulator process started in 10 secs"
    exit 1
  fi
  echo "...wait process... $i sec"
  sleep 1
  i=$((i+1))
done

echo "Wait for the Android emulator device ready..."
i=1
while ! $ANDROID_HOME/platform-tools/adb devices |grep '^emulator-.*device$';do
  if [ $i -eq 60 ];then
    echo "No emulator attached in 1 min"
    $ANDROID_HOME/platform-tools/adb devices
    exit 2
  fi
  if ! $ANDROID_HOME/platform-tools/adb devices |grep -q 'emulator-';then
    echo "Emulator has gone"
    $ANDROID_HOME/platform-tools/adb devices
    exit 3
  fi
  echo "...wait device... $i sec"
  sleep 1
  i=$((i+1))
done

echo "Wait for the Android emulator to boot..."

$ANDROID_HOME/platform-tools/adb shell 'i=1;while [[ -z $(getprop sys.boot_completed | tr -d '\r') ]]; do echo "...wait boot... $i sec";sleep 1; i=$((i+1));done; input keyevent 82'

echo "adb devices..."
$ANDROID_HOME/platform-tools/adb devices

echo "Existing config.ini"

test -f /Users/vsts/.android/avd/Nexus_5X_API_26.avd/config.ini && cat /Users/vsts/.android/avd/Nexus_5X_API_26.avd/config.ini || echo "UNEXPECTED: No config.ini"

echo "Modifying config..."
echo "hw.lcd.width=1080" >> /Users/vsts/.android/avd/Nexus_5X_API_26.avd/config.ini
echo "hw.lcd.height=1920" >> /Users/vsts/.android/avd/Nexus_5X_API_26.avd/config.ini
cat /Users/vsts/.android/avd/Nexus_5X_API_26.avd/config.ini

echo "Installing NVM..."
brew install nvm
source $(brew --prefix nvm)/nvm.sh

echo "Installing v8.5..."
nvm install v8.5.0
nvm use --delete-prefix v8.5.0
nvm alias default v8.5.0

echo "Identifying selected node version..."
node --version

echo "Installing detox cli..."
npm install -g detox-cli

cd $WORK_DIR/examples/demo-react-native

echo "Installing dependencies for detox tests..."
npm install

echo "Building the project..."
./node_modules/.bin/detox build --configuration android.emu.release

echo "Install app..."
$ANDROID_HOME/platform-tools/adb install android/app/build/outputs/apk/release/app-debug.apk

echo "Executing tests..."
./node_modules/.bin/detox test --loglevel verbose --configuration android.emu.release --cleanup --debug-synchronization 1000
