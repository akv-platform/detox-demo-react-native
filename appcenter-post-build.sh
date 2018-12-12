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
  echo "Creating an Android emulator..."
  cd $ANDROID_HOME/tools/bin
  echo "y" | ./sdkmanager "system-images;android-25;google_apis;x86"
  echo "y" | ./sdkmanager --licenses
  touch ~/.android/repositories.cfg

  echo "no" | ./avdmanager create avd --force -n testAVD -k "system-images;android-25;google_apis;x86"

  echo "Modifying config..."
  echo "hw.lcd.width=1080" >> /Users/vsts/.android/avd/testAVD.avd/config.ini
  echo "hw.lcd.height=1920" >> /Users/vsts/.android/avd/testAVD.avd/config.ini

  echo "Starting the Android emulator..."
  cd $ANDROID_HOME/emulator
  emulator -avd testAVD -netdelay none -netspeed full
  cd $APPCENTER_SOURCE_DIRECTORY
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
  echo "Executing tests..." 
  ./node_modules/.bin/detox test --configuration android.emu.debug --cleanup 
fi
