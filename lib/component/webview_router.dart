import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:bot_toast/bot_toast.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:nostrmo/component/cust_state.dart';
import 'package:nostrmo/component/nip07_dialog.dart';
import 'package:nostrmo/consts/base.dart';
import 'package:nostrmo/consts/base_consts.dart';
import 'package:nostrmo/provider/setting_provider.dart';
import 'package:nostrmo/provider/webview_provider.dart';
import 'package:nostrmo/util/lightning_util.dart';
import 'package:nostrmo/util/platform_util.dart';
import 'package:nostrmo/util/router_util.dart';
import 'package:nostrmo/util/string_util.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../client/event.dart';
import '../client/nip04/nip04.dart';
import '../client/nip07/nip07_methods.dart';
import '../generated/l10n.dart';
import '../main.dart';

class WebViewRouter extends StatefulWidget {
  String url;

  WebViewRouter({super.key, required this.url});

  static void open(BuildContext context, String link) {
    if (PlatformUtil.isTableMode()) {
      launchUrl(Uri.parse(link));
      return;
    }
    // Navigator.push(context, MaterialPageRoute(builder: (context) {
    //   return WebViewRouter(url: link);
    // }));
    webViewProvider.open(link);
  }

  @override
  State<StatefulWidget> createState() {
    // return _WebViewRouter();
    return _InAppWebViewRouter();
  }
}

class _InAppWebViewRouter extends CustState<WebViewRouter> {
  final GlobalKey webViewKey = GlobalKey();
  double btnWidth = 40;

  InAppWebViewController? webViewController;
  late ContextMenu contextMenu;
  InAppWebViewSettings settings = InAppWebViewSettings(
      isInspectable: kDebugMode,
      mediaPlaybackRequiresUserGesture: false,
      allowsInlineMediaPlayback: true,
      iframeAllow: "camera; microphone",
      iframeAllowFullscreen: true);

  PullToRefreshController? pullToRefreshController;

  double progress = 0;

  Future<void> nip07Reject(String resultId, String contnet) async {
    var script = "window.nostr.reject(\"$resultId\", \"${contnet}\");";
    await webViewController!.evaluateJavascript(source: script);
    // _controller.runJavaScript(script);
  }

  @override
  void initState() {
    super.initState();

    contextMenu = ContextMenu(
        menuItems: [
          ContextMenuItem(
              id: 1,
              title: "Special",
              action: () async {
                print("Menu item Special clicked!");
                print(await webViewController?.getSelectedText());
                await webViewController?.clearFocus();
              })
        ],
        settings: ContextMenuSettings(hideDefaultSystemContextMenuItems: false),
        onCreateContextMenu: (hitTestResult) async {
          print("onCreateContextMenu");
          print(hitTestResult.extra);
          print(await webViewController?.getSelectedText());
        },
        onHideContextMenu: () {
          print("onHideContextMenu");
        },
        onContextMenuActionItemClicked: (contextMenuItemClicked) async {
          var id = contextMenuItemClicked.id;
          print("onContextMenuActionItemClicked: " +
              id.toString() +
              " " +
              contextMenuItemClicked.title);
        });

    pullToRefreshController = kIsWeb ||
            ![TargetPlatform.iOS, TargetPlatform.android]
                .contains(defaultTargetPlatform)
        ? null
        : PullToRefreshController(
            settings: PullToRefreshSettings(
              color: Colors.blue,
            ),
            onRefresh: () async {
              if (defaultTargetPlatform == TargetPlatform.android) {
                webViewController?.reload();
              } else if (defaultTargetPlatform == TargetPlatform.iOS ||
                  defaultTargetPlatform == TargetPlatform.macOS) {
                webViewController?.loadUrl(
                    urlRequest:
                        URLRequest(url: await webViewController?.getUrl()));
              }
            },
          );
  }

  @override
  Widget doBuild(BuildContext context) {
    var s = S.of(context);
    var themeData = Theme.of(context);
    var paddingTop = mediaDataCache.padding.top;
    var mainColor = themeData.primaryColor;
    var scaffoldBackgroundColor = themeData.scaffoldBackgroundColor;
    var _settingProvider = Provider.of<SettingProvider>(context);
    var _webViewProvider = Provider.of<WebViewProvider>(context);

    var btnTopPosition = Base.BASE_PADDING + Base.BASE_PADDING_HALF;

    var main = Stack(
      children: [
        InAppWebView(
          key: webViewKey,
          initialUrlRequest: URLRequest(url: WebUri(widget.url)),
          // initialUrlRequest:
          // URLRequest(url: WebUri(Uri.base.toString().replaceFirst("/#/", "/") + 'page.html')),
          // initialFile: "assets/index.html",
          initialUserScripts: UnmodifiableListView<UserScript>([]),
          initialSettings: settings,
          contextMenu: contextMenu,
          pullToRefreshController: pullToRefreshController,
          onWebViewCreated: (controller) async {
            webViewController = controller;
            initJSHandle(controller);
          },
          onLoadStart: (controller, url) async {},
          onPermissionRequest: (controller, request) async {
            return PermissionResponse(
                resources: request.resources,
                action: PermissionResponseAction.GRANT);
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            var uri = navigationAction.request.url!;
            if (uri.scheme == "lightning" && StringUtil.isNotBlank(uri.path)) {
              var result =
                  await NIP07Dialog.show(context, NIP07Methods.lightning);
              if (result == true) {
                await LightningUtil.goToPay(context, uri.path);
              }
              return NavigationActionPolicy.CANCEL;
            }

            // if (![
            //   "http",
            //   "https",
            //   "file",
            //   "chrome",
            //   "data",
            //   "javascript",
            //   "about"
            // ].contains(uri.scheme)) {
            //   if (await canLaunchUrl(uri)) {
            //     // Launch the App
            //     await launchUrl(
            //       uri,
            //     );
            //     // and cancel the request
            //     return NavigationActionPolicy.CANCEL;
            //   }
            // }

            return NavigationActionPolicy.ALLOW;
          },
          onLoadStop: (controller, url) async {
            pullToRefreshController?.endRefreshing();
            addInitScript(controller);
          },
          onReceivedError: (controller, request, error) {
            pullToRefreshController?.endRefreshing();
          },
          onProgressChanged: (controller, progress) {
            if (progress == 100) {
              pullToRefreshController?.endRefreshing();
            }
            setState(() {
              this.progress = progress / 100;
            });
          },
          onUpdateVisitedHistory: (controller, url, isReload) {},
          onConsoleMessage: (controller, consoleMessage) {
            print(consoleMessage);
          },
        ),
        progress < 1.0 ? LinearProgressIndicator(value: progress) : Container(),
      ],
    );

    AppBar? appbar;
    late Widget bodyWidget;
    if (_settingProvider.webviewAppbarOpen == OpenStatus.OPEN) {
      bodyWidget = main;
      appbar = AppBar(
        backgroundColor: mainColor,
        leading: GestureDetector(
          onTap: handleBack,
          child: Icon(
            Icons.arrow_back_ios_new,
            color: themeData.appBarTheme.titleTextStyle!.color,
          ),
        ),
        actions: [
          getMoreWidget(Container(
            height: btnWidth,
            width: btnWidth,
            margin: const EdgeInsets.only(right: Base.BASE_PADDING),
            alignment: Alignment.center,
            child: Icon(
              Icons.more_horiz,
              color: themeData.appBarTheme.titleTextStyle!.color,
            ),
          ))
        ],
      );
    } else {
      var lefeBtn = GestureDetector(
        onTap: handleBack,
        child: Container(
          height: btnWidth,
          width: btnWidth,
          decoration: BoxDecoration(
            color: scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(btnWidth / 2),
          ),
          child: Icon(Icons.arrow_back_ios_new),
          alignment: Alignment.center,
        ),
      );

      bodyWidget = Container(
        margin: EdgeInsets.only(top: paddingTop),
        child: Stack(
          children: [
            main,
            Positioned(
              left: Base.BASE_PADDING,
              top: btnTopPosition,
              child: lefeBtn,
            ),
            Positioned(
              right: Base.BASE_PADDING,
              top: btnTopPosition,
              child: getMoreWidget(Container(
                height: btnWidth,
                width: btnWidth,
                decoration: BoxDecoration(
                  color: scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(btnWidth / 2),
                ),
                child: Icon(Icons.more_horiz),
                alignment: Alignment.center,
              )),
            ),
          ],
        ),
      );
    }

    if (_webViewProvider.showable) {
      bodyWidget = WillPopScope(
        child: bodyWidget,
        onWillPop: () async {
          await handleBack();
          return false;
        },
      );
    }

    return Scaffold(
      appBar: appbar,
      body: bodyWidget,
    );
  }

  Widget getMoreWidget(Widget icon) {
    var s = S.of(context);
    var themeData = Theme.of(context);
    var scaffoldBackgroundColor = themeData.scaffoldBackgroundColor;

    return PopupMenuButton<String>(
      itemBuilder: (context) {
        return [
          PopupMenuItem(
            value: "copyCurrentUrl",
            child: Text(s.Copy_current_Url),
          ),
          PopupMenuItem(
            value: "copyInitUrl",
            child: Text(s.Copy_init_Url),
          ),
          PopupMenuItem(
            value: "openInBrowser",
            child: Text(s.Open_in_browser),
          ),
          PopupMenuItem(
            value: "requestPermission",
            child: Text(s.WebRTC_Permission),
          ),
          PopupMenuItem(
            value: "hideBrowser",
            child: Text(s.Hide),
          ),
          PopupMenuItem(
            value: "close",
            child: Text(s.close),
          ),
        ];
      },
      onSelected: onPopupSelected,
      child: icon,
    );
  }

  @override
  Future<void> onReady(BuildContext context) async {}

  Future<void> onPopupSelected(String value) async {
    if (value == "copyCurrentUrl") {
      var url = await webViewController!.getUrl();
      if (StringUtil.isNotBlank(url.toString())) {
        _doCopy(url.toString());
      }
    } else if (value == "copyInitUrl") {
      _doCopy(widget.url);
    } else if (value == "openInBrowser") {
      var _url = Uri.parse(widget.url);
      launchUrl(_url);
    } else if (value == "hideBrowser") {
      webViewProvider.hide();
    } else if (value == "close") {
      webViewProvider.close();
    } else if (value == "requestPermission") {
      await Permission.camera.request();
      await Permission.microphone.request();
    }
  }

  void _doCopy(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      BotToast.showText(text: S.of(context).Copy_success);
    });
  }

  Future<void> handleBack() async {
    var canGoBack = await webViewController!.canGoBack();
    if (canGoBack) {
      webViewController!.goBack();
    } else {
      // RouterUtil.back(context);
      webViewProvider.close();
    }
  }

  @override
  void dispose() {
    webViewController!
        .loadUrl(urlRequest: URLRequest(url: WebUri("about:blank")));
    webViewController!.dispose();
    super.dispose();
    // log("dispose!!!!");
  }

  void initJSHandle(InAppWebViewController controller) {
    controller.addJavaScriptHandler(
      handlerName: "Nostrmo_JS_getPublicKey",
      callback: (jsMsgs) async {
        var jsMsg = jsMsgs[0];
        // print("Nostrmo_JS_getPublicKey $jsMsg");
        var jsonObj = jsonDecode(jsMsg);
        var resultId = jsonObj["resultId"];

        var comfirmResult =
            await NIP07Dialog.show(context, NIP07Methods.getPublicKey);
        if (comfirmResult == true) {
          var pubkey = nostr!.publicKey;
          var script = "window.nostr.callback(\"$resultId\", \"$pubkey\");";
          controller.evaluateJavascript(source: script);
        } else {
          nip07Reject(resultId, S.of(context).Forbid);
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: "Nostrmo_JS_signEvent",
      callback: (jsMsgs) async {
        var jsMsg = jsMsgs[0];
        // print("Nostrmo_JS_signEvent $jsMsg");
        var jsonObj = jsonDecode(jsMsg);
        var resultId = jsonObj["resultId"];
        var content = jsonObj["msg"];

        var comfirmResult = await NIP07Dialog.show(
            context, NIP07Methods.signEvent,
            content: content);

        if (comfirmResult == true) {
          try {
            var eventObj = jsonDecode(content);
            var tags = eventObj["tags"];
            Event event = Event(nostr!.publicKey, eventObj["kind"], tags ?? [],
                eventObj["content"]);
            event.sign(nostr!.privateKey!);

            var eventResultStr = jsonEncode(event.toJson());
            // TODO this method to handle " may be error
            eventResultStr = eventResultStr.replaceAll("\"", "\\\"");
            var script =
                "window.nostr.callback(\"$resultId\", JSON.parse(\"$eventResultStr\"));";
            webViewController!.evaluateJavascript(source: script);
          } catch (e) {
            nip07Reject(resultId, S.of(context).Sign_fail);
          }
        } else {
          nip07Reject(resultId, S.of(context).Forbid);
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: "Nostrmo_JS_getRelays",
      callback: (jsMsgs) async {
        var jsMsg = jsMsgs[0];
        // print("Nostrmo_JS_getRelays $jsMsg");
        var jsonObj = jsonDecode(jsMsg);
        var resultId = jsonObj["resultId"];

        var comfirmResult =
            await NIP07Dialog.show(context, NIP07Methods.getRelays);
        if (comfirmResult == true) {
          var relayMaps = {};
          var relayAddrs = relayProvider.relayAddrs;
          for (var relayAddr in relayAddrs) {
            relayMaps[relayAddr] = {"read": true, "write": true};
          }
          var resultStr = jsonEncode(relayMaps);
          resultStr = resultStr.replaceAll("\"", "\\\"");
          var script =
              "window.nostr.callback(\"$resultId\", JSON.parse(\"$resultStr\"));";
          webViewController!.evaluateJavascript(source: script);
        } else {
          nip07Reject(resultId, S.of(context).Forbid);
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: "Nostrmo_JS_nip04_encrypt",
      callback: (jsMsgs) async {
        var jsMsg = jsMsgs[0];
        // print("Nostrmo_JS_nip04_encrypt $jsMsg");
        var jsonObj = jsonDecode(jsMsg);
        var resultId = jsonObj["resultId"];
        var msg = jsonObj["msg"];
        if (msg != null && msg is Map) {
          var pubkey = msg["pubkey"];
          var plaintext = msg["plaintext"];

          var comfirmResult = await NIP07Dialog.show(
              context, NIP07Methods.nip04_encrypt,
              content: plaintext);
          if (comfirmResult == true) {
            var agreement = NIP04.getAgreement(nostr!.privateKey!);
            var resultStr = NIP04.encrypt(plaintext, agreement, pubkey);
            var script =
                "window.nostr.callback(\"$resultId\", \"$resultStr\");";
            webViewController!.evaluateJavascript(source: script);
          } else {
            nip07Reject(resultId, S.of(context).Forbid);
          }
        }
      },
    );
    controller.addJavaScriptHandler(
      handlerName: "Nostrmo_JS_nip04_decrypt",
      callback: (jsMsgs) async {
        var jsMsg = jsMsgs[0];
        // print("Nostrmo_JS_nip04_decrypt $jsMsg");
        var jsonObj = jsonDecode(jsMsg.message);
        var resultId = jsonObj["resultId"];
        var msg = jsonObj["msg"];
        if (msg != null && msg is Map) {
          var pubkey = msg["pubkey"];
          var ciphertext = msg["ciphertext"];

          var comfirmResult = await NIP07Dialog.show(
              context, NIP07Methods.nip04_decrypt,
              content: ciphertext);
          if (comfirmResult == true) {
            var agreement = NIP04.getAgreement(nostr!.privateKey!);
            var resultStr = NIP04.decrypt(ciphertext, agreement, pubkey);
            var script =
                "window.nostr.callback(\"$resultId\", \"$resultStr\");";
            webViewController!.evaluateJavascript(source: script);
          } else {
            nip07Reject(resultId, S.of(context).Forbid);
          }
        }
      },
    );
  }

  void addInitScript(InAppWebViewController controller) {
    controller.evaluateJavascript(source: """
window.nostr = {
_call(channel, message) {
    return new Promise((resolve, reject) => {
        var resultId = "callbackResult_" + Math.floor(Math.random() * 100000000);
        var arg = {"resultId": resultId};
        if (message) {
            arg["msg"] = message;
        }
        var argStr = JSON.stringify(arg);
        window.flutter_inappwebview
                      .callHandler(channel, argStr);
        window.nostr._requests[resultId] = {resolve, reject}
    });
},
_requests: {},
callback(resultId, message) {
    window.nostr._requests[resultId].resolve(message);
},
reject(resultId, message) {
    window.nostr._requests[resultId].reject(message);
},
async getPublicKey() {
    return window.nostr._call("Nostrmo_JS_getPublicKey");
},
async signEvent(event) {
    return window.nostr._call("Nostrmo_JS_signEvent", JSON.stringify(event));
},
async getRelays() {
    return window.nostr._call("Nostrmo_JS_getRelays");
},
nip04: {
  async encrypt(pubkey, plaintext) {
    return window.nostr._call("Nostrmo_JS_nip04_encrypt", {"pubkey": pubkey, "plaintext": plaintext});
  },
  async decrypt(pubkey, ciphertext) {
      return window.nostr._call("Nostrmo_JS_nip04_decrypt", {"pubkey": pubkey, "ciphertext": ciphertext});
  },
},
};
""");
  }
}

// class _WebViewRouter extends CustState<WebViewRouter> {
//   WebViewController _controller = WebViewController();

//   String? url;

//   double btnWidth = 40;

//   void nip07Reject(String resultId, String contnet) {
//     var script = "window.nostr.reject(\"$resultId\", \"${contnet}\");";
//     _controller.runJavaScript(script);
//   }

// @override
// void initState() {
//   super.initState();
//   _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
//   _controller.addJavaScriptChannel(
//     "Nostrmo_JS_getPublicKey",
//     onMessageReceived: (jsMsg) async {
//       var jsonObj = jsonDecode(jsMsg.message);
//       var resultId = jsonObj["resultId"];

//       var comfirmResult =
//           await NIP07Dialog.show(context, NIP07Methods.getPublicKey);
//       if (comfirmResult == true) {
//         var pubkey = nostr!.publicKey;
//         var script = "window.nostr.callback(\"$resultId\", \"$pubkey\");";
//         _controller.runJavaScript(script);
//       } else {
//         nip07Reject(resultId, S.of(context).Forbid);
//       }
//     },
//   );
//   _controller.addJavaScriptChannel(
//     "Nostrmo_JS_signEvent",
//     onMessageReceived: (jsMsg) async {
//       var jsonObj = jsonDecode(jsMsg.message);
//       var resultId = jsonObj["resultId"];
//       var content = jsonObj["msg"];

//       var comfirmResult = await NIP07Dialog.show(
//           context, NIP07Methods.signEvent,
//           content: content);

//       if (comfirmResult == true) {
//         try {
//           var eventObj = jsonDecode(content);
//           var tags = eventObj["tags"];
//           Event event = Event(nostr!.publicKey, eventObj["kind"], tags ?? [],
//               eventObj["content"]);
//           event.sign(nostr!.privateKey!);

//           var eventResultStr = jsonEncode(event.toJson());
//           // TODO this method to handle " may be error
//           eventResultStr = eventResultStr.replaceAll("\"", "\\\"");
//           var script =
//               "window.nostr.callback(\"$resultId\", JSON.parse(\"$eventResultStr\"));";
//           _controller.runJavaScript(script);
//         } catch (e) {
//           nip07Reject(resultId, S.of(context).Sign_fail);
//         }
//       } else {
//         nip07Reject(resultId, S.of(context).Forbid);
//       }
//     },
//   );
//   _controller.addJavaScriptChannel(
//     "Nostrmo_JS_getRelays",
//     onMessageReceived: (jsMsg) async {
//       var jsonObj = jsonDecode(jsMsg.message);
//       var resultId = jsonObj["resultId"];

//       var comfirmResult =
//           await NIP07Dialog.show(context, NIP07Methods.getRelays);
//       if (comfirmResult == true) {
//         var relayMaps = {};
//         var relayAddrs = relayProvider.relayAddrs;
//         for (var relayAddr in relayAddrs) {
//           relayMaps[relayAddr] = {"read": true, "write": true};
//         }
//         var resultStr = jsonEncode(relayMaps);
//         resultStr = resultStr.replaceAll("\"", "\\\"");
//         var script =
//             "window.nostr.callback(\"$resultId\", JSON.parse(\"$resultStr\"));";
//         _controller.runJavaScript(script);
//       } else {
//         nip07Reject(resultId, S.of(context).Forbid);
//       }
//     },
//   );
//   _controller.addJavaScriptChannel(
//     "Nostrmo_JS_nip04_encrypt",
//     onMessageReceived: (jsMsg) async {
//       var jsonObj = jsonDecode(jsMsg.message);
//       var resultId = jsonObj["resultId"];
//       var msg = jsonObj["msg"];
//       if (msg != null && msg is Map) {
//         var pubkey = msg["pubkey"];
//         var plaintext = msg["plaintext"];

//         var comfirmResult = await NIP07Dialog.show(
//             context, NIP07Methods.nip04_encrypt,
//             content: plaintext);
//         if (comfirmResult == true) {
//           var agreement = NIP04.getAgreement(nostr!.privateKey!);
//           var resultStr = NIP04.encrypt(plaintext, agreement, pubkey);
//           var script = "window.nostr.callback(\"$resultId\", \"$resultStr\");";
//           _controller.runJavaScript(script);
//         } else {
//           nip07Reject(resultId, S.of(context).Forbid);
//         }
//       }
//     },
//   );
//   _controller.addJavaScriptChannel(
//     "Nostrmo_JS_nip04_decrypt",
//     onMessageReceived: (jsMsg) async {
//       var jsonObj = jsonDecode(jsMsg.message);
//       var resultId = jsonObj["resultId"];
//       var msg = jsonObj["msg"];
//       if (msg != null && msg is Map) {
//         var pubkey = msg["pubkey"];
//         var ciphertext = msg["ciphertext"];

//         var comfirmResult = await NIP07Dialog.show(
//             context, NIP07Methods.nip04_decrypt,
//             content: ciphertext);
//         if (comfirmResult == true) {
//           var agreement = NIP04.getAgreement(nostr!.privateKey!);
//           var resultStr = NIP04.decrypt(ciphertext, agreement, pubkey);
//           var script = "window.nostr.callback(\"$resultId\", \"$resultStr\");";
//           _controller.runJavaScript(script);
//         } else {
//           nip07Reject(resultId, S.of(context).Forbid);
//         }
//       }
//     },
//   );
//   _controller.setNavigationDelegate(NavigationDelegate(
//     onWebResourceError: (error) {
//       print(error);
//     },
//     onPageFinished: (url) {
//       _controller.runJavaScript("""
// window.nostr = {
// _call(channel, message) {
//     return new Promise((resolve, reject) => {
//         var resultId = "callbackResult_" + Math.floor(Math.random() * 100000000);
//         var arg = {"resultId": resultId};
//         if (message) {
//             arg["msg"] = message;
//         }
//         var argStr = JSON.stringify(arg);
//         channel.postMessage(argStr);
//         window.nostr._requests[resultId] = {resolve, reject}
//     });
// },
// _requests: {},
// callback(resultId, message) {
//     window.nostr._requests[resultId].resolve(message);
// },
// reject(resultId, message) {
//     window.nostr._requests[resultId].reject(message);
// },
// async getPublicKey() {
//     return window.nostr._call(Nostrmo_JS_getPublicKey);
// },
// async signEvent(event) {
//     return window.nostr._call(Nostrmo_JS_signEvent, JSON.stringify(event));
// },
// async getRelays() {
//     return window.nostr._call(Nostrmo_JS_getRelays);
// },
// nip04: {
//   async encrypt(pubkey, plaintext) {
//     return window.nostr._call(Nostrmo_JS_nip04_encrypt, {"pubkey": pubkey, "plaintext": plaintext});
//   },
//   async decrypt(pubkey, ciphertext) {
//       return window.nostr._call(Nostrmo_JS_nip04_decrypt, {"pubkey": pubkey, "ciphertext": ciphertext});
//   },
// },
// };
// """);
//     },
//   ));
// }

//   @override
//   Widget doBuild(BuildContext context) {
//     var s = S.of(context);
//     var themeData = Theme.of(context);
//     var paddingTop = mediaDataCache.padding.top;
//     var mainColor = themeData.primaryColor;
//     var scaffoldBackgroundColor = themeData.scaffoldBackgroundColor;
//     var _settingProvider = Provider.of<SettingProvider>(context);
//     var _webViewProvider = Provider.of<WebViewProvider>(context);

//     if (url != null && widget.url != url) {
//       url = widget.url;
//       _controller.loadRequest(Uri.parse(widget.url));
//     }

//     var btnTopPosition = Base.BASE_PADDING + Base.BASE_PADDING_HALF;

//     var main = WebViewWidget(
//       controller: _controller,
//     );

//     AppBar? appbar;
//     late Widget bodyWidget;
//     if (_settingProvider.webviewAppbarOpen == OpenStatus.OPEN) {
//       bodyWidget = main;
//       appbar = AppBar(
//         backgroundColor: mainColor,
//         leading: GestureDetector(
//           child: Icon(Icons.arrow_back_ios_new),
//           onTap: handleBack,
//         ),
//         actions: [
//           getMoreWidget(Container(
//             height: btnWidth,
//             width: btnWidth,
//             margin: EdgeInsets.only(right: Base.BASE_PADDING),
//             child: Icon(Icons.more_horiz),
//             alignment: Alignment.center,
//           ))
//         ],
//       );
//     } else {
//       var lefeBtn = GestureDetector(
//         onTap: handleBack,
//         child: Container(
//           height: btnWidth,
//           width: btnWidth,
//           decoration: BoxDecoration(
//             color: scaffoldBackgroundColor,
//             borderRadius: BorderRadius.circular(btnWidth / 2),
//           ),
//           child: Icon(Icons.arrow_back_ios_new),
//           alignment: Alignment.center,
//         ),
//       );

//       bodyWidget = Container(
//         margin: EdgeInsets.only(top: paddingTop),
//         child: Stack(
//           children: [
//             main,
//             Positioned(
//               left: Base.BASE_PADDING,
//               top: btnTopPosition,
//               child: lefeBtn,
//             ),
//             Positioned(
//               right: Base.BASE_PADDING,
//               top: btnTopPosition,
//               child: getMoreWidget(Container(
//                 height: btnWidth,
//                 width: btnWidth,
//                 decoration: BoxDecoration(
//                   color: scaffoldBackgroundColor,
//                   borderRadius: BorderRadius.circular(btnWidth / 2),
//                 ),
//                 child: Icon(Icons.more_horiz),
//                 alignment: Alignment.center,
//               )),
//             ),
//           ],
//         ),
//       );
//     }

//     if (_webViewProvider.showable) {
//       bodyWidget = WillPopScope(
//         child: bodyWidget,
//         onWillPop: () async {
//           await handleBack();
//           return false;
//         },
//       );
//     }

//     return Scaffold(
//       appBar: appbar,
//       body: bodyWidget,
//     );
//   }

//   Widget getMoreWidget(Widget icon) {
//     var s = S.of(context);
//     var themeData = Theme.of(context);
//     var scaffoldBackgroundColor = themeData.scaffoldBackgroundColor;

//     return PopupMenuButton<String>(
//       itemBuilder: (context) {
//         return [
//           PopupMenuItem(
//             value: "copyCurrentUrl",
//             child: Text(s.Copy_current_Url),
//           ),
//           PopupMenuItem(
//             value: "copyInitUrl",
//             child: Text(s.Copy_init_Url),
//           ),
//           PopupMenuItem(
//             value: "openInBrowser",
//             child: Text(s.Open_in_browser),
//           ),
//           PopupMenuItem(
//             value: "requestPermission",
//             child: Text("requestPermission"),
//           ),
//           PopupMenuItem(
//             value: "hideBrowser",
//             child: Text(s.Hide),
//           ),
//           PopupMenuItem(
//             value: "close",
//             child: Text(s.close),
//           ),
//         ];
//       },
//       onSelected: onPopupSelected,
//       child: icon,
//     );
//   }

//   @override
//   Future<void> onReady(BuildContext context) async {
//     _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
//     url = widget.url;
//     _controller.loadRequest(Uri.parse(widget.url));
//   }

//   Future<void> onPopupSelected(String value) async {
//     var url = await _controller.currentUrl();
//     if (value == "copyCurrentUrl") {
//       if (StringUtil.isNotBlank(url)) {
//         _doCopy(url!);
//       }
//     } else if (value == "copyInitUrl") {
//       _doCopy(widget.url);
//     } else if (value == "openInBrowser") {
//       var _url = Uri.parse(widget.url);
//       launchUrl(_url);
//     } else if (value == "hideBrowser") {
//       webViewProvider.hide();
//     } else if (value == "close") {
//       webViewProvider.close();
//     } else if (value == "requestPermission") {
//       await Permission.camera.request();
//       await Permission.microphone.request();
//     }
//   }

//   void _doCopy(String text) {
//     Clipboard.setData(ClipboardData(text: text)).then((_) {
//       BotToast.showText(text: S.of(context).Copy_success);
//     });
//   }

//   Future<void> handleBack() async {
//     var canGoBack = await _controller.canGoBack();
//     if (canGoBack) {
//       _controller.goBack();
//     } else {
//       // RouterUtil.back(context);
//       webViewProvider.close();
//     }
//   }

//   @override
//   void dispose() {
//     super.dispose();
//     _controller.loadRequest(Uri.parse('about:blank'));
//     // log("dispose!!!!");
//   }
// }
