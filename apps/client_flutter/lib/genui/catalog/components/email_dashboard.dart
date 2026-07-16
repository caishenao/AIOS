import 'package:flutter/material.dart';
import '../catalog_registry.dart';
import '../theme_tokens.dart';

class EmailDashboardComponent extends StatefulWidget {
  final List<dynamic> emails;
  final int? unreadCount;
  final String? selectedEmailId;
  final ThemeTokens theme;
  final Map<String, String>? events;
  final EventCallback? onEvent;

  const EmailDashboardComponent({
    super.key,
    required this.emails,
    this.unreadCount,
    this.selectedEmailId,
    required this.theme,
    this.events,
    this.onEvent,
  });

  static void register(CatalogRegistry registry) {
    registry.register('EmailDashboard', ({
      required props,
      required children,
      bindings,
      events,
      theme,
      required context,
      onEvent,
    }) {
      return EmailDashboardComponent(
        emails: props['emails'] as List<dynamic>? ?? [],
        unreadCount: props['unreadCount'] as int?,
        selectedEmailId: props['selectedEmailId'] as String?,
        theme: theme ?? ThemeTokens.minimal,
        events: events,
        onEvent: onEvent,
      );
    });
  }

  @override
  State<EmailDashboardComponent> createState() => _EmailDashboardComponentState();
}

class _EmailDashboardComponentState extends State<EmailDashboardComponent> {
  String? _localSelectedEmailId;
  bool _isComposing = false;
  
  final _toController = TextEditingController();
  final _subjectController = TextEditingController();
  final _bodyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _localSelectedEmailId = widget.selectedEmailId;
  }

  @override
  void dispose() {
    _toController.dispose();
    _subjectController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.theme;
    final int unread = widget.unreadCount ?? widget.emails.where((e) => e['read'] == false).length;

    return Container(
      decoration: BoxDecoration(
        color: t.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(t.cardRadius),
        border: Border.all(color: t.accent.withAlpha(40)),
        boxShadow: [
          BoxShadow(
            color: t.accent.withAlpha(20),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: t.baseSpacing, vertical: t.baseSpacing * 0.8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [t.accent.withAlpha(40), Colors.transparent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(bottom: BorderSide(color: t.accent.withAlpha(30))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.mail_outline, color: t.accent, size: 24),
                    SizedBox(width: t.baseSpacing * 0.5),
                    Text(
                      'AIOS 邮件',
                      style: TextStyle(
                        color: t.onSurface,
                        fontSize: 18 * t.fontScale,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (unread > 0) ...[
                      SizedBox(width: t.baseSpacing * 0.5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: t.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$unread 封未读',
                          style: TextStyle(
                            color: t.onAccent,
                            fontSize: 10 * t.fontScale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                IconButton(
                  icon: Icon(_isComposing ? Icons.close : Icons.edit, color: t.accent),
                  onPressed: () {
                    setState(() {
                      _isComposing = !_isComposing;
                      _localSelectedEmailId = null;
                    });
                  },
                ),
              ],
            ),
          ),

          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isComposing
                ? _buildComposeForm(t)
                : _localSelectedEmailId != null
                    ? _buildEmailDetail(t)
                    : _buildEmailList(t),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailList(ThemeTokens t) {
    if (widget.emails.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(t.baseSpacing * 2),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: t.onSurface.withAlpha(40)),
              SizedBox(height: t.baseSpacing),
              Text(
                '收件箱中无邮件',
                style: TextStyle(color: t.onSurface.withAlpha(120), fontSize: 14 * t.fontScale),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.emails.length,
      separatorBuilder: (_, __) => Divider(color: t.onSurface.withAlpha(15), height: 1),
      itemBuilder: (context, index) {
        final email = widget.emails[index] as Map<String, dynamic>;
        final isRead = email['read'] as bool? ?? true;
        final isSelected = _localSelectedEmailId == email['id'];

        return InkWell(
          onTap: () {
            setState(() {
              _localSelectedEmailId = email['id'];
            });
            final action = widget.events?['onEmailTap'] ?? 'email.tap';
            widget.onEvent?.call(action, {'id': email['id']});
          },
          child: Container(
            padding: EdgeInsets.all(t.baseSpacing),
            decoration: BoxDecoration(
              color: isSelected
                  ? t.accent.withAlpha(20)
                  : !isRead
                      ? t.accent.withAlpha(8)
                      : Colors.transparent,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        email['sender'] ?? '',
                        style: TextStyle(
                          color: isRead ? t.onSurface.withAlpha(200) : t.onSurface,
                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          fontSize: 14 * t.fontScale,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      email['date'] ?? '',
                      style: TextStyle(
                        color: t.onSurface.withAlpha(100),
                        fontSize: 11 * t.fontScale,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email['subject'] ?? '',
                  style: TextStyle(
                    color: t.onSurface,
                    fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                    fontSize: 15 * t.fontScale,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  email['snippet'] ?? '',
                  style: TextStyle(
                    color: t.onSurface.withAlpha(140),
                    fontSize: 13 * t.fontScale,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmailDetail(ThemeTokens t) {
    final email = widget.emails.firstWhere(
      (e) => e['id'] == _localSelectedEmailId,
      orElse: () => null,
    );

    if (email == null) {
      return Container();
    }

    return Padding(
      padding: EdgeInsets.all(t.baseSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: Icon(Icons.arrow_back, color: t.accent, size: 18),
                label: Text('返回', style: TextStyle(color: t.accent)),
                onPressed: () {
                  setState(() {
                    _localSelectedEmailId = null;
                  });
                },
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.reply, color: t.onSurface.withAlpha(180)),
                    onPressed: () {
                      setState(() {
                        _isComposing = true;
                        _toController.text = email['sender'] ?? '';
                        _subjectController.text = 'Re: ${email['subject'] ?? ''}';
                        _bodyController.text = '\n\nOn ${email['date']}, ${email['sender']} wrote:\n> ${email['snippet']}';
                        _localSelectedEmailId = null;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.redAccent.withAlpha(200)),
                    onPressed: () {
                      final action = widget.events?['onEmailDelete'] ?? 'email.delete';
                      widget.onEvent?.call(action, {'id': email['id']});
                      setState(() {
                        _localSelectedEmailId = null;
                      });
                    },
                  ),
                ],
              )
            ],
          ),
          const Divider(height: 20),
          Text(
            email['subject'] ?? '',
            style: TextStyle(
              color: t.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 18 * t.fontScale,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                backgroundColor: t.accent.withAlpha(40),
                child: Text(
                  (email['sender'] as String? ?? 'U').substring(0, 1).toUpperCase(),
                  style: TextStyle(color: t.accent, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email['sender'] ?? '',
                      style: TextStyle(color: t.onSurface, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      email['date'] ?? '',
                      style: TextStyle(color: t.onSurface.withAlpha(120), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            email['snippet'] ?? '',
            style: TextStyle(
              color: t.onSurface.withAlpha(220),
              fontSize: 15 * t.fontScale,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildComposeForm(ThemeTokens t) {
    return Padding(
      padding: EdgeInsets.all(t.baseSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '撰写新邮件',
            style: TextStyle(
              color: t.onSurface,
              fontWeight: FontWeight.bold,
              fontSize: 16 * t.fontScale,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _toController,
            style: TextStyle(color: t.onSurface),
            decoration: InputDecoration(
              labelText: '收件人',
              labelStyle: TextStyle(color: t.onSurface.withAlpha(120)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.onSurface.withAlpha(40))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subjectController,
            style: TextStyle(color: t.onSurface),
            decoration: InputDecoration(
              labelText: '主题',
              labelStyle: TextStyle(color: t.onSurface.withAlpha(120)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.onSurface.withAlpha(40))),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: t.accent)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyController,
            maxLines: 5,
            style: TextStyle(color: t.onSurface),
            decoration: InputDecoration(
              labelText: '邮件正文',
              labelStyle: TextStyle(color: t.onSurface.withAlpha(120)),
              border: OutlineInputBorder(borderSide: BorderSide(color: t.onSurface.withAlpha(40))),
              enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: t.onSurface.withAlpha(40))),
              focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: t.accent)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isComposing = false;
                  });
                },
                child: Text('取消', style: TextStyle(color: t.onSurface.withAlpha(160))),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('发送'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: t.accent,
                  foregroundColor: t.onAccent,
                ),
                onPressed: () {
                  final action = widget.events?['onEmailSend'] ?? 'email.send';
                  widget.onEvent?.call(action, {
                    'to': _toController.text,
                    'subject': _subjectController.text,
                    'body': _bodyController.text,
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('邮件发送成功 (模拟)')),
                  );

                  _toController.clear();
                  _subjectController.clear();
                  _bodyController.clear();
                  
                  setState(() {
                    _isComposing = false;
                  });
                },
              )
            ],
          ),
        ],
      ),
    );
  }
}
