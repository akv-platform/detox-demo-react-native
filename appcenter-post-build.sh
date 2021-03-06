if [ -z "$APPCENTER_ANDROID_VARIANT"];
then 
  echo "Installing applesimutils..."
  mkdir simutils
  cd simutils
  curl https://raw.githubusercontent.com/wix/homebrew-brew/master/AppleSimulatorUtils-0.5.22.tar.gz -o applesimutils.tar.gz
  tar xzvf applesimutils.tar.gz
  sh buildForBrew.sh .
  cd ..
  export PATH=$PATH:./simutils/build/Build/Products/Release
else
  spctl kext-consent list
  echo "------------------------------------LOG---------------------------------------------------------------"
  echo "Creating an Android emulator..."
  cd $ANDROID_HOME/tools/bin
  echo "y" | ./sdkmanager "system-images;android-25;google_apis;arm64-v8a"
  for i in {1..4};do echo "y"; done | ./sdkmanager --licenses
  touch ~/.android/repositories.cfg

  echo "no" | ./avdmanager create avd --force -n Nexus_5X_API_26 -k "system-images;android-25;google_apis;arm64-v8a" 

  echo "LOG: emulator -list-avds"
  $ANDROID_HOME/emulator/emulator -list-avds

  echo "Starting the Android emulator..."
  
  cd $ANDROID_HOME/emulator
  cd $(dirname $(which emulator))
  nohup emulator -avd Nexus_5X_API_26 -no-snapshot > /dev/null 2>&1 &
  sleep 5
 
  echo "Wait for the Android emulator to run..."
  $ANDROID_HOME/platform-tools/adb wait-for-device shell 'while [[ -z $(getprop sys.boot_completed | tr -d '\r') ]]; do sleep 1; done; input keyevent 82'
  echo "Ensure emulator run..."
  $ANDROID_HOME/platform-tools/adb devices

  echo "----------------------------"
  echo "LOG: nohup.out"
  cat nohup.out
  echo "LOG: spctl kext-consent list"
  spctl kext-consent list
  echo "----------------------------"

  echo "Ensure emulator run:"
  $ANDROID_HOME/platform-tools/adb devices

  echo "LOG : adb shell ls"
  $ANDROID_HOME/platform-tools/adb wait-for-device shell ls

  cd $APPCENTER_SOURCE_DIRECTORY

	echo "Existing config.ini"

	test -f /Users/vsts/.android/avd/Nexus_5X_API_26.avd/config.ini && cat /Users/vsts/.android/avd/Nexus_5X_API_26.avd/config.ini || echo "UNEXPECTED: No config.ini"

  echo "Modifying config..."
  echo "hw.lcd.width=1080" >> /Users/vsts/.android/avd/Nexus_5X_API_26.avd/config.ini
  echo "hw.lcd.height=1920" >> /Users/vsts/.android/avd/Nexus_5X_API_26.avd/config.ini
fi

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

echo "Installing dependencies for detox tests..."
npm install


if [ -z "$APPCENTER_ANDROID_VARIANT"];
then 
  echo "Building the project..." 
  ./node_modules/.bin/detox build --configuration ios.sim.release 
  echo "Executing tests..." 
  ./node_modules/.bin/detox test --configuration ios.sim.release --cleanup
else
  echo "Building the project..." 
  ./node_modules/.bin/detox build --configuration android.emu.debug

  echo "Install app..." 
  $ANDROID_HOME/platform-tools/adb install android/app/build/outputs/apk/debug/app-debug.apk

  echo "Executing tests..." 
  ./node_modules/.bin/detox test --loglevel verbose --configuration android.emu.debug --cleanup --debug-synchronization 1000
fi
