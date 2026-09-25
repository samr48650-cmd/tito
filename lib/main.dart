import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

const _primaryColor = Color(0xFF0066CC);
const _accentColor = Color(0xFF1E90FF);
const _surfaceColor = Color(0xFF17212B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const TitoApp());
}

class TitoApp extends StatelessWidget {
  const TitoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tito Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B141B),
        primaryColor: _primaryColor,
        colorScheme: const ColorScheme.dark(
          primary: _primaryColor,
          secondary: _accentColor,
          surface: _surfaceColor,
        ),
      ),
      home: FirebaseAuth.instance.currentUser == null
          ? const PhoneAuthScreen()
          : const HomeScreen(),
    );
  }
}

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phoneController = TextEditingController();
  final _smsController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  String? _verificationId;
  bool _codeSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _smsController.dispose();
    super.dispose();
  }

  Future<void> _sendSmsCode() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 8) {
      _showSnackBar('Enter a valid phone number with country code.');
      return;
    }

    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (credential) async {
        await _auth.signInWithCredential(credential);
        await _onAuthSuccess();
      },
      verificationFailed: (error) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _showSnackBar('Verification failed: ${error.message ?? error.code}');
      },
      codeSent: (verificationId, _) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _codeSent = true;
          _isLoading = false;
        });
        _showSnackBar('SMS code sent.');
      },
      codeAutoRetrievalTimeout: (verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  Future<void> _verifyCode() async {
    final smsCode = _smsController.text.trim();
    if (smsCode.isEmpty || _verificationId == null) {
      _showSnackBar('Enter the SMS code.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      await _auth.signInWithCredential(credential);
      await _onAuthSuccess();
    } on FirebaseAuthException {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackBar('The SMS code is invalid or expired.');
    }
  }

  Future<void> _onAuthSuccess() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'phoneNumber': user.phoneNumber,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 80, color: _accentColor),
              const SizedBox(height: 16),
              const Text('Welcome to Tito Chat', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Enter your phone number to receive an SMS verification code.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (!_codeSent)
                _PhoneEntry(controller: _phoneController, onSubmit: _sendSmsCode)
              else
                _CodeEntry(controller: _smsController, onSubmit: _verifyCode),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneEntry extends StatelessWidget {
  const _PhoneEntry({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TextField(controller: controller, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone number (e.g. +1234567890)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: onSubmit, child: const Text('Send SMS code'))),
        ],
      );
}

class _CodeEntry extends StatelessWidget {
  const _CodeEntry({required this.controller, required this.onSubmit});
  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TextField(controller: controller, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: '6-digit SMS code', border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock))),
          const SizedBox(height: 16),
          SizedBox(width: double.infinity, height: 48, child: ElevatedButton(onPressed: onSubmit, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('Verify and login'))),
        ],
      );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const PhoneAuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(backgroundColor: _surfaceColor, title: const Text('Tito Chat'), actions: [IconButton(icon: const Icon(Icons.logout), tooltip: 'Log out', onPressed: () => _signOut(context))]),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text('Could not load users: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final users = snapshot.data?.docs.where((doc) => doc.id != currentUid).toList() ?? [];
          if (users.isEmpty) return const Center(child: Text('No other users registered yet.'));
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index].data();
              return ListTile(
                leading: const CircleAvatar(backgroundColor: _primaryColor, child: Icon(Icons.person, color: Colors.white)),
                title: Text(user['phoneNumber'] as String? ?? 'Unknown user'),
                subtitle: const Text('Tap to start chatting'),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrivateChatScreen(targetUid: user['uid'] as String, targetPhone: user['phoneNumber'] as String? ?? 'Unknown user'))),
              );
            },
          );
        },
      ),
    );
  }
}

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({super.key, required this.targetUid, required this.targetPhone});
  final String targetUid;
  final String targetPhone;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _messageController = TextEditingController();
  final _currentUid = FirebaseAuth.instance.currentUser!.uid;

  String get _chatRoomId {
    final ids = [_currentUid, widget.targetUid]..sort();
    return ids.join('_');
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await FirebaseFirestore.instance.collection('chats').doc(_chatRoomId).collection('messages').add({
      'senderId': _currentUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: _surfaceColor, title: Text(widget.targetPhone)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('chats').doc(_chatRoomId).collection('messages').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Could not load messages: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data();
                    final isMe = data['senderId'] == _currentUid;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: isMe ? _primaryColor : _surfaceColor, borderRadius: BorderRadius.circular(12)),
                        child: Text(data['text'] as String? ?? '', style: const TextStyle(color: Colors.white, fontSize: 15)),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            color: _surfaceColor,
            child: Row(children: [Expanded(child: TextField(controller: _messageController, textInputAction: TextInputAction.send, onSubmitted: (_) => _sendMessage(), decoration: const InputDecoration(hintText: 'Type a message...', border: InputBorder.none))), IconButton(icon: const Icon(Icons.send, color: _accentColor), tooltip: 'Send message', onPressed: _sendMessage)]),
          ),
        ],
      ),
    );
  }
}
