import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:real_time_collaboration_application/chat/widget/bottom_chat_field.dart';
import 'package:real_time_collaboration_application/common/colors.dart';
import 'package:real_time_collaboration_application/global_variable.dart';
import 'package:real_time_collaboration_application/providers/taskProvider.dart';
import 'package:real_time_collaboration_application/providers/userProvider.dart';
import 'package:real_time_collaboration_application/common/socket.dart'; // Import SocketService

class ChatScreen extends StatefulWidget {
  final String taskId;
  const ChatScreen({Key? key, required this.taskId}) : super(key: key);
  static const String routeName = '/chat-screen';

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController messageController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  List<Map<String, dynamic>> messages = [];
  bool isShowEmojiContainer = false;
  bool isShowSendButton = false;
  late TaskProvider taskProvider;
  late UserProvider userProvider;
  late SocketService socketService;

  @override
  void initState() {
    super.initState();
    taskProvider = Provider.of<TaskProvider>(context, listen: false);
    userProvider = Provider.of<UserProvider>(context, listen: false);
    socketService = Provider.of<SocketService>(context, listen: false);
    setupSocketConnection();
  }

  @override
  void dispose() {
   // socketService.leaveRoom(widget.taskId);
  //CHANGES  
    socketService.leaveTask(widget.taskId, userProvider.user.id);
    socketService.offEvent("messages"); // Remove event listeners
    socketService.offEvent("messageCreated");
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void setupSocketConnection() {
    socketService.joinRoom(widget.taskId);

    socketService.onEvent("messages", (data) {
      if (mounted) {
        setState(() {
          messages = List<Map<String, dynamic>>.from(data);
        });
        scrollToBottom();
      }
    });
    
     socketService.onEvent("messageCreated", (data) {
       if (mounted) {
        setState(() {
          messages.add(data);
          
        });
        scrollToBottom();
       }
      });

    socketService.emitEvent("getmessages", widget.taskId);
  }

  void sendTextMessage() {
    if (messageController.text.trim().isNotEmpty) {
      final message = messageController.text.trim();
      final data = {
        "taskId": widget.taskId,
        "userId": userProvider.user.id,
        "message": message,
        "username": userProvider.user.username,
        "timestamp": DateTime.now().toUtc().toIso8601String(),
      };
      socketService.emitEvent("createmessage", data);
     
      setState(() {
        messageController.clear();
        isShowSendButton = false;
      });
    }
  }

  void toggleEmojiKeyboardContainer() {
    setState(() {
      isShowEmojiContainer = !isShowEmojiContainer;
    });
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = Provider.of<UserProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat Screen'),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientColor1, gradientColor2, gradientColor1],
            stops: [0.2, 0.5, 1.0],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      color: messageColor,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 5,
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(5.0),
                            child: Text(
                              message['userId'] == userProvider.user.id
                                  ? 'You'
                                  : message['username'],
                              style: TextStyle(
                                color: Colors.green[200],
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              children: [
                                Text(
                                  message['message'],
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            message['timestamp'] != null
                                ? DateFormat('hh:mm a').format(
                                    DateTime.parse(message['timestamp'])
                                        .toLocal(), // Convert to local time
                                  )
                                : 'N/A',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            BottomChatField(
              messageController: messageController,
              onSend: sendTextMessage,
              onToggleEmojiKeyboard: toggleEmojiKeyboardContainer,
              isShowEmojiContainer: isShowEmojiContainer,
              isShowSendButton: isShowSendButton,
              onTextChanged: (text) {
                setState(() {
                  isShowSendButton = text.trim().isNotEmpty;
                });
              },
            ),
            if (isShowEmojiContainer)
              SizedBox(
                height: 310,
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) {
                    messageController.text += emoji.emoji;
                    setState(() {
                      isShowSendButton =
                          messageController.text.trim().isNotEmpty;
                    });
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
