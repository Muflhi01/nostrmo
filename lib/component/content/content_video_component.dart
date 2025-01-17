import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nostrmo/consts/base.dart';
import 'package:nostrmo/util/store_util.dart';
import 'package:widget_size/widget_size.dart';

import '../../consts/base64.dart';

class ContentVideoComponent extends StatefulWidget {
  String url;

  ContentVideoComponent({required this.url});

  @override
  State<StatefulWidget> createState() {
    return _ContentVideoComponent();
  }
}

class _ContentVideoComponent extends State<ContentVideoComponent> {
  // Create a [Player] to control playback.
  late final player = Player();
  // Create a [VideoController] to handle video output from [Player].
  late final controller = VideoController(player);

  // VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.url.indexOf("http") == 0) {
      player.open(Media(widget.url), play: false);
      // _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      //   ..initialize().then((_) {
      //     setState(() {});
      //   });
    } else if (widget.url.startsWith(BASE64.PREFIX)) {
      StoreUtil.saveBS2TempFileByMd5("mp4", BASE64.toData(widget.url))
          .then((tempFileName) {
        player.open(Media("file:///$tempFileName"), play: false);
        // _controller = VideoPlayerController.file(File(tempFileName))
        //   ..initialize().then((_) {
        //     setState(() {});
        //   });
      });
    } else {
      player.open(Media("file:///${widget.url}"), play: false);
      // _controller = VideoPlayerController.file(File(widget.url))
      //   ..initialize().then((_) {
      //     setState(() {});
      //   });
    }
  }

  @override
  void dispose() {
    super.dispose();
    controller.player.stop();
    controller.player.dispose();
  }

  double? width;

  @override
  Widget build(BuildContext context) {
    var currentwidth = MediaQuery.of(context).size.width;
    if (width != null) {
      currentwidth = width!;
    }

    return Container(
      margin: const EdgeInsets.only(
        top: Base.BASE_PADDING_HALF,
        bottom: Base.BASE_PADDING_HALF,
      ),
      child: WidgetSize(
        onChange: ((size) {
          setState(() {
            width = size.width;
          });
        }),
        child: Center(
          child: SizedBox(
            width: currentwidth,
            height: currentwidth * 9.0 / 16.0,
            // Use [Video] widget to display video output.
            child: Video(controller: controller),
          ),
        ),
      ),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   if (_controller == null) {
  //     return Container();
  //   }

  //   return Container(
  //     width: double.maxFinite,
  //     margin: const EdgeInsets.only(
  //       top: Base.BASE_PADDING_HALF,
  //       bottom: Base.BASE_PADDING_HALF,
  //     ),
  //     child: Center(
  //       child: _controller!.value.isInitialized
  //           ? AspectRatio(
  //               aspectRatio: _controller!.value.aspectRatio,
  //               child: Stack(
  //                 alignment: Alignment.bottomCenter,
  //                 children: <Widget>[
  //                   VideoPlayer(_controller!),
  //                   ControlsOverlay(controller: _controller!),
  //                   VideoProgressIndicator(_controller!, allowScrubbing: true),
  //                 ],
  //               ),
  //             )
  //           : Container(),
  //     ),
  //   );
  // }
}

// class ControlsOverlay extends StatefulWidget {
//   final VideoPlayerController controller;

//   ControlsOverlay({required this.controller});

//   @override
//   State<StatefulWidget> createState() {
//     return _ControlsOverlay();
//   }
// }

// class _ControlsOverlay extends State<ControlsOverlay> {
//   late VideoPlayerController controller;

//   static const List<Duration> _exampleCaptionOffsets = <Duration>[
//     Duration(seconds: -10),
//     Duration(seconds: -3),
//     Duration(seconds: -1, milliseconds: -500),
//     Duration(milliseconds: -250),
//     Duration.zero,
//     Duration(milliseconds: 250),
//     Duration(seconds: 1, milliseconds: 500),
//     Duration(seconds: 3),
//     Duration(seconds: 10),
//   ];
//   static const List<double> _examplePlaybackRates = <double>[
//     0.25,
//     0.5,
//     1.0,
//     1.5,
//     2.0,
//     3.0,
//     5.0,
//     10.0,
//   ];

//   @override
//   void initState() {
//     super.initState();
//     controller = widget.controller;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Stack(
//       children: <Widget>[
//         AnimatedSwitcher(
//           duration: const Duration(milliseconds: 50),
//           reverseDuration: const Duration(milliseconds: 200),
//           child: controller.value.isPlaying
//               ? const SizedBox.shrink()
//               : Container(
//                   color: Colors.black26,
//                   child: const Center(
//                     child: Icon(
//                       Icons.play_arrow,
//                       color: Colors.white,
//                       size: 100.0,
//                       semanticLabel: 'Play',
//                     ),
//                   ),
//                 ),
//         ),
//         GestureDetector(
//           onTap: () {
//             controller.value.isPlaying ? controller.pause() : controller.play();
//             setState(() {});
//           },
//         ),
//         Align(
//           alignment: Alignment.topLeft,
//           child: PopupMenuButton<Duration>(
//             initialValue: controller.value.captionOffset,
//             tooltip: 'Caption Offset',
//             onSelected: (Duration delay) {
//               controller.setCaptionOffset(delay);
//             },
//             itemBuilder: (BuildContext context) {
//               return <PopupMenuItem<Duration>>[
//                 for (final Duration offsetDuration in _exampleCaptionOffsets)
//                   PopupMenuItem<Duration>(
//                     value: offsetDuration,
//                     child: Text('${offsetDuration.inMilliseconds}ms'),
//                   )
//               ];
//             },
//             child: Padding(
//               padding: const EdgeInsets.symmetric(
//                 // Using less vertical padding as the text is also longer
//                 // horizontally, so it feels like it would need more spacing
//                 // horizontally (matching the aspect ratio of the video).
//                 vertical: 12,
//                 horizontal: 16,
//               ),
//               child: Text('${controller.value.captionOffset.inMilliseconds}ms'),
//             ),
//           ),
//         ),
//         Align(
//           alignment: Alignment.topRight,
//           child: PopupMenuButton<double>(
//             initialValue: controller.value.playbackSpeed,
//             tooltip: 'Playback speed',
//             onSelected: (double speed) {
//               controller.setPlaybackSpeed(speed);
//             },
//             itemBuilder: (BuildContext context) {
//               return <PopupMenuItem<double>>[
//                 for (final double speed in _examplePlaybackRates)
//                   PopupMenuItem<double>(
//                     value: speed,
//                     child: Text('${speed}x'),
//                   )
//               ];
//             },
//             child: Padding(
//               padding: const EdgeInsets.symmetric(
//                 // Using less vertical padding as the text is also longer
//                 // horizontally, so it feels like it would need more spacing
//                 // horizontally (matching the aspect ratio of the video).
//                 vertical: 12,
//                 horizontal: 16,
//               ),
//               child: Text('${controller.value.playbackSpeed}x'),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
// }
