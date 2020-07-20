//
//MIT License
//
//Copyright (c) [2019] [Befovy]
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.
//

part of fijkplayer;

/// [FijkAudioView] is a widget that can display the video frame of [FijkPlayer].
///
/// Actually, it is a Container widget contains many children.
/// The most important is a Texture which display the read video frame.
class FijkAudioView extends StatefulWidget {
  FijkAudioView({
    @required this.player,
    this.width,
    this.height,
    this.fit = FijkFit.contain,
    this.fsFit = FijkFit.contain,
    this.panelBuilder = defaultFijkPanelBuilder,
    this.color = const Color(0xFF607D8B),
    this.cover,
    this.fs = true,
    this.onDispose,
  }) : assert(player != null);

  /// The player that need display video by this [FijkAudioView].
  /// Will be passed to [panelBuilder].
  final FijkPlayer player;

  /// builder to build panel Widget
  final FijkPanelWidgetBuilder panelBuilder;

  /// This method will be called when fijkAudioView dispose.
  /// FijkData is managed inner FijkAudioView. User can change fijkData in custom panel.
  /// See [panelBuilder]'s second argument.
  /// And check if some value need to be recover on FijkAudioView dispose.
  final void Function(FijkData) onDispose;

  /// background color
  final Color color;

  /// cover image provider
  final ImageProvider cover;

  /// How a video should be inscribed into this [FijkAudioView].
  final FijkFit fit;

  /// How a video should be inscribed into this [FijkAudioView] at fullScreen mode.
  final FijkFit fsFit;

  /// Nullable, width of [FijkAudioView]
  /// If null, the weight will be as big as possible.
  final double width;

  /// Nullable, height of [FijkAudioView].
  /// If null, the height will be as big as possible.
  final double height;

  /// Enable or disable the full screen
  ///
  /// If [fs] is true, FijkAudioView make response to the [FijkValue.fullScreen] value changed,
  /// and push o new full screen mode page when [FijkValue.fullScreen] is true, pop full screen page when [FijkValue.fullScreen]  become false.
  ///
  /// If [fs] is false, FijkAudioView never make response to the change of [FijkValue.fullScreen].
  /// But you can still call [FijkPlayer.enterFullScreen] and [FijkPlayer.exitFullScreen] and make your own full screen pages.
  final bool fs;

  @override
  createState() => _FijkAudioViewState();
}

class _FijkAudioViewState extends State<FijkAudioView> {
  int _textureId = -1;
  double _vWidth = -1;
  double _vHeight = -1;
  bool _fullScreen = false;

  FijkData _fijkData;
  ValueNotifier<int> paramNotifier = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _fijkData = FijkData();
    Size s = widget.player.value.size;
    if (s != null) {
      _vWidth = s.width;
      _vHeight = s.height;
    }
    widget.player.addListener(_fijkValueListener);
    _nativeSetup();
  }

  Future<void> _nativeSetup() async {
    if (widget.player.value.prepared) {
      _setupTexture();
    }
    paramNotifier.value = paramNotifier.value + 1;
  }

  void _setupTexture() async {
    final int vid = await widget.player.setupSurface();
    FijkLog.i("view setup, vid:" + vid.toString());
    if (mounted) {
      setState(() {
        _textureId = vid;
      });
    }
  }

  void _fijkValueListener() async {
    FijkValue value = widget.player.value;
    if (value.prepared && _textureId < 0) {
      _setupTexture();
    }

    if (widget.fs) {
      if (value.fullScreen && !_fullScreen) {
        _fullScreen = true;
        await _pushFullScreenWidget(context);
      } else if (_fullScreen && !value.fullScreen) {
        Navigator.of(context).pop();
        _fullScreen = false;
      }

      // save width and height to make judgement about whether to
      // request landscape when enter full screen mode
      if (value.size != null && value.prepared) {
        _vWidth = value.size.width;
        _vHeight = value.size.height;
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.player.removeListener(_fijkValueListener);

    var brightness = _fijkData.getValue(FijkData._fijkViewPanelBrightness);
    if (brightness != null && brightness is double) {
      FijkPlugin.setScreenBrightness(brightness);
      _fijkData.clearValue(FijkData._fijkViewPanelBrightness);
    }

    var volume = _fijkData.getValue(FijkData._fijkViewPanelVolume);
    if (volume != null && volume is double) {
      FijkVolume.setVol(volume);
      _fijkData.clearValue(FijkData._fijkViewPanelVolume);
    }

    if (widget.onDispose != null) {
      widget.onDispose(_fijkData);
    }
  }

  AnimatedWidget _defaultRoutePageBuilder(
      BuildContext context, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget child) {
        return Scaffold(
          resizeToAvoidBottomInset: false,
          body: _InnerFijkAudioView(
            fijkAudioViewState: this,
            fullScreen: true,
            cover: widget.cover,
            data: _fijkData,
          ),
        );
      },
    );
  }

  Widget _fullScreenRoutePageBuilder(BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation) {
    return _defaultRoutePageBuilder(context, animation);
  }

  Future<dynamic> _pushFullScreenWidget(BuildContext context) async {
    final TransitionRoute<Null> route = PageRouteBuilder<Null>(
      settings: RouteSettings(),
      pageBuilder: _fullScreenRoutePageBuilder,
    );

    await SystemChrome.setEnabledSystemUIOverlays([]);
    bool changed = false;
    var orientation = MediaQuery.of(context).orientation;
    FijkLog.d("start enter fullscreen. orientation:$orientation");
    if (_vWidth >= _vHeight) {
      if (MediaQuery.of(context).orientation == Orientation.portrait)
        changed = await FijkPlugin.setOrientationLandscape();
    } else {
      if (MediaQuery.of(context).orientation == Orientation.landscape)
        changed = await FijkPlugin.setOrientationPortrait();
    }
    FijkLog.d("screen orientation changed:$changed");

    await Navigator.of(context).push(route);
    _fullScreen = false;
    widget.player.exitFullScreen();
    await SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.top, SystemUiOverlay.bottom]);
    if (changed) {
      if (_vWidth >= _vHeight) {
        await FijkPlugin.setOrientationPortrait();
      } else {
        await FijkPlugin.setOrientationLandscape();
      }
    }
  }

  @override
  void didUpdateWidget(Widget oldWidget) {
    super.didUpdateWidget(oldWidget);
    paramNotifier.value = paramNotifier.value + 1;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      child: _fullScreen
          ? Container()
          : _InnerFijkAudioView(
              fijkAudioViewState: this,
              fullScreen: false,
              cover: widget.cover,
              data: _fijkData,
            ),
    );
  }
}

class _InnerFijkAudioView extends StatefulWidget {
  _InnerFijkAudioView({
    @required this.fijkAudioViewState,
    @required this.fullScreen,
    @required this.cover,
    @required this.data,
  }) : assert(fijkAudioViewState != null);

  final _FijkAudioViewState fijkAudioViewState;
  final bool fullScreen;
  final ImageProvider cover;
  final FijkData data;

  @override
  __InnerFijkAudioViewState createState() => __InnerFijkAudioViewState();
}

class __InnerFijkAudioViewState extends State<_InnerFijkAudioView> {
  FijkPlayer _player;
  FijkPanelWidgetBuilder _panelBuilder;
  Color _color;
  FijkFit _fit;
  int _textureId;
  double _vWidth = -1;
  double _vHeight = -1;
  bool _vFullScreen = false;
  int _degree = 0;
  bool _videoRender = false;

  @override
  void initState() {
    super.initState();
    _player = fView.player;
    _fijkValueListener();
    fView.player.addListener(_fijkValueListener);
    if (widget.fullScreen) {
      widget.fijkAudioViewState.paramNotifier.addListener(_voidValueListener);
    }
  }

  FijkAudioView get fView => widget.fijkAudioViewState.widget;

  void _voidValueListener() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _fijkValueListener());
  }

  void _fijkValueListener() {
    if (!mounted) return;

    FijkPanelWidgetBuilder panelBuilder = fView.panelBuilder;
    Color color = fView.color;
    FijkFit fit = widget.fullScreen ? fView.fsFit : fView.fit;
    int textureId = widget.fijkAudioViewState._textureId;

    FijkValue value = _player.value;

    _degree = value.rotate;
    double width = _vWidth;
    double height = _vHeight;
    bool fullScreen = value.fullScreen;
    bool videoRender = value.videoRenderStart;

    if (value.size != null && value.prepared) {
      width = value.size.width;
      height = value.size.height;
    }

    if (width != _vWidth ||
        height != _vHeight ||
        fullScreen != _vFullScreen ||
        panelBuilder != _panelBuilder ||
        color != _color ||
        fit != _fit ||
        textureId != _textureId ||
        _videoRender != videoRender) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Size applyAspectRatio(BoxConstraints constraints, double aspectRatio) {
    assert(constraints.hasBoundedHeight && constraints.hasBoundedWidth);

    constraints = constraints.loosen();

    double width = constraints.maxWidth;
    double height = width;

    if (width.isFinite) {
      height = width / aspectRatio;
    } else {
      height = constraints.maxHeight;
      width = height * aspectRatio;
    }

    if (width > constraints.maxWidth) {
      width = constraints.maxWidth;
      height = width / aspectRatio;
    }

    if (height > constraints.maxHeight) {
      height = constraints.maxHeight;
      width = height * aspectRatio;
    }

    if (width < constraints.minWidth) {
      width = constraints.minWidth;
      height = width / aspectRatio;
    }

    if (height < constraints.minHeight) {
      height = constraints.minHeight;
      width = height * aspectRatio;
    }

    return constraints.constrain(Size(width, height));
  }

  double getAspectRatio(BoxConstraints constraints, double ar) {
    if (ar == null || ar < 0) {
      ar = _vWidth / _vHeight;
    } else if (ar.isInfinite) {
      ar = constraints.maxWidth / constraints.maxHeight;
    }
    return ar;
  }

  /// calculate Texture size
  Size getTxSize(BoxConstraints constraints, FijkFit fit) {
    Size childSize = applyAspectRatio(
        constraints, getAspectRatio(constraints, fit.aspectRatio));
    double sizeFactor = fit.sizeFactor;
    if (-1.0 < sizeFactor && sizeFactor < -0.0) {
      sizeFactor = max(constraints.maxWidth / childSize.width,
          constraints.maxHeight / childSize.height);
    } else if (-2.0 < sizeFactor && sizeFactor < -1.0) {
      sizeFactor = constraints.maxWidth / childSize.width;
    } else if (-3.0 < sizeFactor && sizeFactor < -2.0) {
      sizeFactor = constraints.maxHeight / childSize.height;
    } else if (sizeFactor < 0) {
      sizeFactor = 1.0;
    }
    childSize = childSize * sizeFactor;
    return childSize;
  }

  /// calculate Texture offset
  Offset getTxOffset(BoxConstraints constraints, Size childSize, FijkFit fit) {
    final Alignment resolvedAlignment = fit.alignment;
    final Offset diff = constraints.biggest - childSize;
    return resolvedAlignment.alongOffset(diff);
  }

  Widget buildTexture() {
    Widget tex = _textureId > 0 ? Texture(textureId: _textureId) : Container();
    if (_degree != 0 && _textureId > 0) {
      return RotatedBox(
        quarterTurns: _degree ~/ 90,
        child: tex,
      );
    }
    return tex;
  }

  @override
  void dispose() {
    super.dispose();
    fView.player.removeListener(_fijkValueListener);
    widget.fijkAudioViewState.paramNotifier.removeListener(_fijkValueListener);
  }

  @override
  Widget build(BuildContext context) {
    _panelBuilder = fView.panelBuilder;
    _color = fView.color;
    _fit = widget.fullScreen ? fView.fsFit : fView.fit;
    _textureId = widget.fijkAudioViewState._textureId;

    FijkValue value = _player.value;
    FijkData data = widget.data;
    if (value.size != null && value.prepared) {
      _vWidth = value.size.width;
      _vHeight = value.size.height;
    }
    _videoRender = value.videoRenderStart;

    return LayoutBuilder(builder: (ctx, constraints) {
      // get child size
      final Size childSize = getTxSize(constraints, _fit);
      final Offset offset = getTxOffset(constraints, childSize, _fit);
      final Rect pos = Rect.fromLTWH(
          offset.dx, offset.dy, childSize.width, childSize.height);

      List ws = <Widget>[
        Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          color: _color,
        ),
      ];

      if (_panelBuilder != null) {
        ws.add(_panelBuilder(_player, data, ctx, constraints.biggest, pos));
      }
      return Stack(
        children: ws,
      );
    });
  }
}
