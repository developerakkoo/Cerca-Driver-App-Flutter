import 'package:flutter/material.dart';
import 'package:driver_cerca/models/message_model.dart';
import 'package:driver_cerca/models/ride_model.dart';
import 'package:driver_cerca/services/message_service.dart';
import 'package:driver_cerca/services/socket_service.dart';
import 'package:driver_cerca/services/storage_service.dart';
import 'package:driver_cerca/constants/constants.dart';
import 'package:intl/intl.dart';

/// ChatScreen for in-ride messaging between driver and rider
class ChatScreen extends StatefulWidget {
  final RideModel ride;

  const ChatScreen({super.key, required this.ride});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = false;
  bool _isSending = false;
  String? _driverId;

  // Quick reply templates
  final List<String> _quickReplies = [
    "I'm on my way!",
    "Arriving in 5 minutes",
    "I'm here",
    "Please wait a moment",
    "Thank you!",
  ];

  @override
  void initState() {
    super.initState();
    _loadDriverId();
    _setupMessageListener();
    _joinRideRoom();
  }

  void _joinRideRoom() {
    print('🚪 [ChatScreen] Joining ride room...');
    print('   Ride ID: ${widget.ride.id}');

    // Wait for socket connection before joining
    if (SocketService.isConnected) {
      SocketService.joinRideRoom(widget.ride.id);
      print('✅ [ChatScreen] Joined ride room');
    } else {
      print('⚠️ [ChatScreen] Socket not connected, will join when connected');
      // Try again after a delay
      Future.delayed(const Duration(seconds: 1), () {
        if (SocketService.isConnected && mounted) {
          SocketService.joinRideRoom(widget.ride.id);
          print('✅ [ChatScreen] Joined ride room after delay');
        }
      });
    }
  }

  @override
  void dispose() {
    // Leave ride room when closing chat
    print('🚪 [ChatScreen] Leaving ride room...');
    SocketService.leaveRideRoom(widget.ride.id);

    _messageController.dispose();
    _scrollController.dispose();
    SocketService.onMessageReceived = null;
    SocketService.onRideMessages = null;
    super.dispose();
  }

  Future<void> _loadDriverId() async {
    print('🚀 ========================================');
    print('🚀 [ChatScreen] _loadDriverId() called');
    print('🚀 ========================================');
    print('⏰ Timestamp: ${DateTime.now().toIso8601String()}');

    _driverId = await StorageService.getDriverId();
    print('👤 [ChatScreen] Driver ID: ${_driverId ?? "null"}');
    print('🆔 [ChatScreen] Ride ID: ${widget.ride.id}');

    // Mark all messages as read when opening chat
    if (_driverId != null) {
      print('📖 [ChatScreen] Marking all messages as read...');
      try {
        await MessageService.markAllMessagesAsRead(widget.ride.id, _driverId!);
        print('✅ [ChatScreen] All messages marked as read');
      } catch (e) {
        print('❌ [ChatScreen] Error marking messages as read: $e');
      }
    } else {
      print('⚠️ [ChatScreen] Driver ID is null, cannot mark messages as read');
    }

    print('📚 [ChatScreen] Loading messages...');
    _loadMessages();
    print('✅ [ChatScreen] _loadDriverId() completed');
    print('========================================');
  }

  void _setupMessageListener() {
    print('👂 ========================================');
    print('👂 [ChatScreen] _setupMessageListener() called');
    print('👂 ========================================');
    print('🆔 [ChatScreen] Ride ID: ${widget.ride.id}');

    // Listen for new messages via socket
    SocketService.onMessageReceived = (message) {
      print('📨 [ChatScreen] onMessageReceived callback triggered');
      print('   Message ID: ${message.id}');
      print('   Message Ride ID: ${message.rideId}');
      print('   Current Ride ID: ${widget.ride.id}');
      print(
        '   Message text: ${message.message.substring(0, message.message.length > 50 ? 50 : message.message.length)}${message.message.length > 50 ? "..." : ""}',
      );
      print('   Mounted: $mounted');

      if (message.rideId == widget.ride.id && mounted) {
        // Filter self-sent messages - ignore messages sent by current driver
        // The driver already has the message from optimistic update
        if (_driverId != null && message.sender.id == _driverId) {
          print('⚠️ [ChatScreen] Ignoring self-sent message');
          print('   Message sender ID: ${message.sender.id}');
          print('   Current driver ID: $_driverId');
          print('   Message will be updated via REST API response instead');
          return;
        }

        // Prevent duplicates
        final messageExists = _messages.any((m) => m.id == message.id);
        print('   Message exists: $messageExists');
        print('   Current messages count: ${_messages.length}');

        if (!messageExists) {
          print('✅ [ChatScreen] Adding new message to list...');
          setState(() {
            _messages.add(message);
            // Sort by createdAt
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            print('✅ [ChatScreen] Message added, total: ${_messages.length}');
            _scrollToBottom();
          });
        } else {
          print('⚠️ [ChatScreen] Duplicate message ignored: ${message.id}');
        }
      } else {
        if (message.rideId != widget.ride.id) {
          print('⚠️ [ChatScreen] Message ride ID mismatch, ignoring');
        }
        if (!mounted) {
          print('⚠️ [ChatScreen] Widget not mounted, ignoring message');
        }
      }
    };
    print('✅ [ChatScreen] onMessageReceived listener set up');

    // Listen for ride messages (chat history) via socket
    SocketService.onRideMessages = (messages) {
      print('📚 [ChatScreen] onRideMessages callback triggered');
      print('   Messages count: ${messages.length}');
      print('   Mounted: $mounted');

      if (mounted) {
        // Filter messages for this ride
        final rideMessages = messages
            .where((m) => m.rideId == widget.ride.id)
            .toList();
        print('   Filtered messages for this ride: ${rideMessages.length}');

        if (rideMessages.isNotEmpty) {
          print('✅ [ChatScreen] Processing ride messages...');
          setState(() {
            // Build sets for duplicate detection: by ID and by content hash
            final existingIds = _messages.map((m) => m.id).toSet();
            final existingContentHashes = _messages
                .where(
                  (m) => !existingIds.contains(m.id),
                ) // Only check optimistic messages
                .map(
                  (m) => '${m.message}_${m.createdAt.millisecondsSinceEpoch}',
                )
                .toSet();

            print('   Existing message IDs: ${existingIds.length}');
            print(
              '   Existing content hashes: ${existingContentHashes.length}',
            );

            // Filter out duplicates by both ID and content hash
            final newMessages = rideMessages.where((m) {
              final hasId = existingIds.contains(m.id);
              if (hasId) {
                return false; // Duplicate by ID
              }

              // Check content hash for optimistic messages
              final contentHash =
                  '${m.message}_${m.createdAt.millisecondsSinceEpoch}';
              final hasContent = existingContentHashes.contains(contentHash);
              if (hasContent) {
                print(
                  '   Duplicate detected by content hash: ${m.message.substring(0, 30)}...',
                );
                return false; // Duplicate by content
              }

              return true; // New message
            }).toList();

            print('   New messages to add: ${newMessages.length}');
            print(
              '   Duplicates filtered: ${rideMessages.length - newMessages.length}',
            );

            _messages.addAll(newMessages);
            _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
            print('✅ [ChatScreen] Messages merged, total: ${_messages.length}');
            _scrollToBottom();
          });
        } else {
          print('ℹ️ [ChatScreen] No messages for this ride in socket response');
        }
      } else {
        print('⚠️ [ChatScreen] Widget not mounted, ignoring ride messages');
      }
    };
    print('✅ [ChatScreen] onRideMessages listener set up');

    // Request messages via socket as backup
    print('📡 [ChatScreen] Requesting messages via socket...');
    SocketService.getRideMessages(widget.ride.id);
    print('✅ [ChatScreen] _setupMessageListener() completed');
    print('========================================');
  }

  Future<void> _loadMessages() async {
    print('📚 ========================================');
    print('📚 [ChatScreen] _loadMessages() called');
    print('📚 ========================================');
    print('🆔 [ChatScreen] Ride ID: ${widget.ride.id}');
    print('⏰ [ChatScreen] Timestamp: ${DateTime.now().toIso8601String()}');

    setState(() => _isLoading = true);
    print('🔄 [ChatScreen] Loading state set to true');

    try {
      print('🌐 [ChatScreen] Calling MessageService.getRideMessages...');
      final messages = await MessageService.getRideMessages(widget.ride.id);
      print('✅ [ChatScreen] Messages fetched - count: ${messages.length}');

      // Sort messages by createdAt timestamp
      messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      print('🔄 [ChatScreen] Messages sorted by createdAt');

      setState(() {
        _messages = messages;
      });
      print(
        '✅ [ChatScreen] Messages set in state - total: ${_messages.length}',
      );

      if (messages.isNotEmpty) {
        print(
          '   First message: ${messages.first.id} at ${messages.first.createdAt}',
        );
        print(
          '   Last message: ${messages.last.id} at ${messages.last.createdAt}',
        );
      }

      _scrollToBottom();
      print(
        '✅ [ChatScreen] Loaded ${messages.length} messages for ride ${widget.ride.id}',
      );
    } catch (e, stackTrace) {
      print('❌ [ChatScreen] Error loading messages: $e');
      print('   Error type: ${e.runtimeType}');
      print('   Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error loading messages: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
      print('🔄 [ChatScreen] Loading state set to false');
      print('✅ [ChatScreen] _loadMessages() completed');
      print('========================================');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    print('💬 ========================================');
    print('💬 [ChatScreen] _sendMessage() called');
    print('💬 ========================================');
    print(
      '📝 [ChatScreen] Message text: ${text.substring(0, text.length > 50 ? 50 : text.length)}${text.length > 50 ? "..." : ""}',
    );
    print('📝 [ChatScreen] Message length: ${text.length}');
    print('👤 [ChatScreen] Driver ID: ${_driverId ?? "null"}');
    print('🆔 [ChatScreen] Ride ID: ${widget.ride.id}');
    print('👤 [ChatScreen] Receiver ID: ${widget.ride.rider?.id ?? "null"}');
    print('⏰ [ChatScreen] Timestamp: ${DateTime.now().toIso8601String()}');

    if (text.trim().isEmpty) {
      print('⚠️ [ChatScreen] Message is empty, cannot send');
      return;
    }

    if (_driverId == null) {
      print('⚠️ [ChatScreen] Driver ID is null, cannot send');
      return;
    }

    setState(() => _isSending = true);
    print('🔄 [ChatScreen] Sending state set to true');

    try {
      // Send via socket first (for real-time delivery)
      print('📡 [ChatScreen] Sending message via Socket.IO...');
      SocketService.sendMessage(
        rideId: widget.ride.id,
        receiverId: widget.ride.rider!.id,
        message: text.trim(),
      );
      print('✅ [ChatScreen] Socket.IO sendMessage() called');

      // Optimistically add message to UI
      print('✨ [ChatScreen] Creating optimistic message...');
      final optimisticMessage = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(), // Temporary ID
        rideId: widget.ride.id,
        sender: SenderInfo(id: _driverId!, role: SenderRole.driver),
        receiver: ReceiverInfo(
          id: widget.ride.rider!.id,
          role: ReceiverRole.rider,
        ),
        message: text.trim(),
        messageType: MessageType.text,
        isRead: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      print(
        '✅ [ChatScreen] Optimistic message created - ID: ${optimisticMessage.id}',
      );

      setState(() {
        _messages.add(optimisticMessage);
        print(
          '✅ [ChatScreen] Optimistic message added to UI - total: ${_messages.length}',
        );
        _scrollToBottom();
      });

      // Also send via REST API for persistence
      print('🌐 [ChatScreen] Sending message via REST API...');
      final sentMessage = await MessageService.sendMessage(
        rideId: widget.ride.id,
        senderId: _driverId!,
        senderRole: SenderRole.driver,
        receiverId: widget.ride.rider!.id,
        receiverRole: ReceiverRole.rider,
        message: text.trim(),
      );
      print('✅ [ChatScreen] Message sent via REST API successfully');
      print('   Sent message ID: ${sentMessage.id}');
      print('   Sent message timestamp: ${sentMessage.createdAt}');

      // Update optimistic message with actual ID and data from backend
      if (mounted) {
        print(
          '🔄 [ChatScreen] Updating optimistic message with server data...',
        );
        setState(() {
          // First try to find by temporary ID
          int index = _messages.indexWhere((m) => m.id == optimisticMessage.id);

          // If not found by ID, try to find by content and timestamp match (within 5 seconds)
          if (index == -1) {
            print(
              '   Optimistic message not found by ID, searching by content...',
            );
            index = _messages.indexWhere((m) {
              // Must be an optimistic message (temporary ID format)
              if (m.id == sentMessage.id) {
                return false; // Already has server ID
              }

              // Match by text content
              if (m.message != optimisticMessage.message) {
                return false;
              }

              // Check if timestamp is within 5 seconds (to account for network delay)
              final timeDiff = m.createdAt
                  .difference(optimisticMessage.createdAt)
                  .abs();
              return timeDiff.inSeconds < 5;
            });

            if (index != -1) {
              print(
                '   Found optimistic message by content match at index: $index',
              );
            }
          }

          if (index != -1) {
            print('✅ [ChatScreen] Found optimistic message at index: $index');
            _messages[index] = sentMessage;
            print(
              '✅ [ChatScreen] Optimistic message updated with server ID: ${sentMessage.id}',
            );
          } else {
            print(
              '⚠️ [ChatScreen] Optimistic message not found, checking for duplicates...',
            );
            // If optimistic message was not found (e.g., due to quick navigation), check if message already exists
            final messageExists = _messages.any((m) => m.id == sentMessage.id);
            if (!messageExists) {
              print('✅ [ChatScreen] Adding confirmed message to list...');
              _messages.add(sentMessage);
            } else {
              print(
                '⚠️ [ChatScreen] Confirmed message already exists in list, skipping',
              );
            }
          }
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          print('✅ [ChatScreen] Messages sorted, total: ${_messages.length}');
        });
      } else {
        print('⚠️ [ChatScreen] Widget not mounted, cannot update UI');
      }

      _messageController.clear();
      print('✅ [ChatScreen] Message controller cleared');
      _scrollToBottom();
      print('✅ [ChatScreen] Scrolled to bottom');
    } catch (e, stackTrace) {
      print('❌ [ChatScreen] Error sending message: $e');
      print('   Error type: ${e.runtimeType}');
      print('   Stack trace: $stackTrace');

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Failed to send message: $e')));
      }
    } finally {
      setState(() => _isSending = false);
      print('🔄 [ChatScreen] Sending state set to false');
      print('✅ [ChatScreen] _sendMessage() completed');
      print('========================================');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ride.rider?.fullName ?? 'Chat'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Quick replies
          if (_messages.isEmpty) _buildQuickReplies(),

          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to start the conversation',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),

          // Message input
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Replies',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _quickReplies.map((reply) {
              return ActionChip(
                label: Text(reply),
                onPressed: () {
                  _messageController.text = reply;
                },
                backgroundColor: Colors.white,
                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message) {
    final isMe = message.sender.id == _driverId;
    final time = DateFormat('h:mm a').format(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
              ),
              child: Text(
                message.message,
                style: TextStyle(
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  time,
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14,
                    color: message.isRead ? AppColors.primary : Colors.grey,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: null,
              enabled: !_isSending,
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.primary,
            child: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      final text = _messageController.text;
                      if (text.trim().isNotEmpty) {
                        _sendMessage(text);
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
