import 'package:flutter/material.dart';
import 'package:get_time_ago/get_time_ago.dart';
import 'package:nostr_dart/nostr_dart.dart';
import 'package:nostrmo/client/nip04/nip04.dart';
import 'package:pointycastle/export.dart' as pointycastle;

import '../../component/user_pic_component.dart';
import '../../consts/base.dart';

class DMDetailItemComponent extends StatefulWidget {
  String sessionPubkey;

  Event event;

  bool isLocal;

  pointycastle.ECDHBasicAgreement agreement;

  DMDetailItemComponent({
    required this.sessionPubkey,
    required this.event,
    required this.isLocal,
    required this.agreement,
  });

  @override
  State<StatefulWidget> createState() {
    return _DMDetailItemComponent();
  }
}

class _DMDetailItemComponent extends State<DMDetailItemComponent> {
  static const double IMAGE_WIDTH = 34;

  @override
  Widget build(BuildContext context) {
    var themeData = Theme.of(context);
    var mainColor = themeData.appBarTheme.backgroundColor;
    var userHeadWidget = UserPicComponent(
      pubkey: widget.event.pubKey,
      width: IMAGE_WIDTH,
    );
    var maxWidth = MediaQuery.of(context).size.width;
    var smallTextSize = themeData.textTheme.bodySmall!.fontSize;
    var hintColor = themeData.hintColor;

    String timeStr = GetTimeAgo.parse(
        DateTime.fromMillisecondsSinceEpoch(widget.event.createdAt * 1000));

    var content = NIP04.decrypt(
        widget.event.content, widget.agreement, widget.sessionPubkey);

    var contentWidget = Container(
      margin: EdgeInsets.only(
        left: Base.BASE_PADDING_HALF,
        right: Base.BASE_PADDING_HALF,
      ),
      child: Column(
        crossAxisAlignment:
            !widget.isLocal ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            timeStr,
            style: TextStyle(
              color: hintColor,
              fontSize: smallTextSize,
            ),
          ),
          Container(
            margin: EdgeInsets.only(top: 4),
            padding: EdgeInsets.all(Base.BASE_PADDING_HALF),
            constraints:
                BoxConstraints(maxWidth: (maxWidth - IMAGE_WIDTH) * 0.85),
            decoration: BoxDecoration(
              // color: Colors.red,
              color: mainColor?.withOpacity(0.3),
              borderRadius: BorderRadius.all(Radius.circular(5)),
            ),
            child: SelectableText(content),
          ),
        ],
      ),
    );

    List<Widget> list = [];
    if (widget.isLocal) {
      list.add(Expanded(child: Container()));
      list.add(contentWidget);
      list.add(userHeadWidget);
    } else {
      list.add(userHeadWidget);
      list.add(contentWidget);
      list.add(Expanded(child: Container()));
    }

    return Container(
      padding: EdgeInsets.all(Base.BASE_PADDING_HALF),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list,
      ),
    );
  }
}