# Tito Chat

A Flutter/Firebase real-time chat app with phone-number authentication.

## Setup

1. Install Flutter and configure an Android or iOS device.
2. Create a Firebase project and enable Phone Authentication and Cloud Firestore.
3. From the project root, install the Firebase CLI and FlutterFire CLI, then run:

	```sh
	flutterfire configure
	```

4. Add the generated Android/iOS Firebase configuration files, then run:

	```sh
	flutter pub get
	flutter run
	```

Before production use, configure Firestore security rules so users can only read permitted profiles and chat messages.
