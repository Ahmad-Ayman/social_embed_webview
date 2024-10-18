library social_embed_webview;

import 'package:flutter/material.dart';
import 'package:social_embed_webview/platforms/social-media-generic.dart';
import 'package:social_embed_webview/utils/common-utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class SocialEmbed extends StatefulWidget {
  final SocialMediaGenericEmbedData socialMediaObj;
  final Color? backgroundColor;
  const SocialEmbed(
      {Key? key, required this.socialMediaObj, this.backgroundColor})
      : super(key: key);

  @override
  _SocialEmbedState createState() => _SocialEmbedState();
}

class _SocialEmbedState extends State<SocialEmbed> with WidgetsBindingObserver {
  double _height = 300;
  late final WebViewController wbController;
  late String htmlBody;

  @override
  void initState() {
    super.initState();
    wbController = WebViewController();
    // htmlBody = ;
    if (widget.socialMediaObj.supportMediaControll)
      WidgetsBinding.instance!.addObserver(this);
  }

  @override
  void dispose() {
    if (widget.socialMediaObj.supportMediaControll)
      WidgetsBinding.instance!.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App is visible and running
        break;
      case AppLifecycleState.inactive:
        // App is inactive, usually when in the foreground but not responding to user input
        wbController.runJavaScript(widget.socialMediaObj.pauseVideoScript);
        break;
      case AppLifecycleState.paused:
        // App is not visible to the user, like in background
        wbController.runJavaScript(widget.socialMediaObj.pauseVideoScript);
        break;
      case AppLifecycleState.detached:
        // App is detached, like when it is closed
        wbController.runJavaScript(widget.socialMediaObj.stopVideoScript);
        break;
      case AppLifecycleState.hidden:
        // App is hidden (specific to certain platforms like Android)
        wbController.runJavaScript(widget.socialMediaObj.pauseVideoScript);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final wv = WebViewWidget(
      controller: wbController
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'PageHeight',
          onMessageReceived: _getHeightJavascriptChannel,
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageFinished: (str) {
              final color = colorToHtmlRGBA(getBackgroundColor(context));
              wbController.runJavaScript(
                  'document.body.style= "background-color: $color"');
              if (widget.socialMediaObj.aspectRatio == null) {
                wbController.runJavaScript('setTimeout(() => sendHeight(), 0)');
              }
            },
            onNavigationRequest: (navigation) async {
              final url = navigation.url;
              if (await canLaunchUrl(Uri.parse(url))) {
                launchUrl(Uri.parse(url));
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(Uri.parse(htmlToURI(getHtmlBody()))),
    );
    final ar = widget.socialMediaObj.aspectRatio;
    return (ar != null)
        ? ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height / 1.5,
              maxWidth: double.infinity,
            ),
            child: AspectRatio(aspectRatio: ar, child: wv),
          )
        : SizedBox(height: _height, child: wv);
  }

  void _getHeightJavascriptChannel(JavaScriptMessage message) {
    _setHeight(double.parse(message.message));
  }

  void _setHeight(double height) {
    setState(() {
      _height = height + widget.socialMediaObj.bottomMargin;
    });
  }

  Color getBackgroundColor(BuildContext context) {
    return widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
  }

  String getHtmlBody() => """
      <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            *{box-sizing: border-box;margin:0px; padding:0px;}
              #widget {
                        display: flex;
                        justify-content: center;
                        margin: 0 auto;
                        max-width:100%;
                    }      
          </style>
        </head>
        <body>
          <div id="widget" style="${widget.socialMediaObj.htmlInlineStyling}">${widget.socialMediaObj.htmlBody}</div>
          ${(widget.socialMediaObj.aspectRatio == null) ? dynamicHeightScriptSetup : ''}
          ${(widget.socialMediaObj.canChangeSize) ? dynamicHeightScriptCheck : ''}
        </body>
      </html>
    """;

  static const String dynamicHeightScriptSetup = """
    <script type="text/javascript">
      const widget = document.getElementById('widget');
      const sendHeight = () => PageHeight.postMessage(widget.clientHeight);
    </script>
  """;

  static const String dynamicHeightScriptCheck = """
    <script type="text/javascript">
      const onWidgetResize = (widgets) => sendHeight();
      const resize_ob = new ResizeObserver(onWidgetResize);
      resize_ob.observe(widget);
    </script>
  """;
}
