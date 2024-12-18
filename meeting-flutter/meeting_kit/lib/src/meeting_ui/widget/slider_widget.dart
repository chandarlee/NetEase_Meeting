// Copyright (c) 2022 NetEase, Inc. All rights reserved.
// Use of this source code is governed by a MIT license that can be
// found in the LICENSE file.

part of meeting_ui;

class SliderWidget extends StatefulWidget {
  final Function(int value) onChange;
  final Function()? closeCallBack;
  final int level;
  final bool? isShowClose;
  final Color? color;

  SliderWidget({
    required this.onChange,
    required this.level,
    this.isShowClose,
    this.closeCallBack,
    this.color,
  });

  @override
  State<StatefulWidget> createState() => _SliderDemo();
}

class _SliderDemo extends State<SliderWidget> {
  late int _level;

  @override
  void initState() {
    super.initState();
    _level = widget.level;
  }

  @override
  void didUpdateWidget(covariant SliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _level = widget.level;
  }

  @override
  Widget build(BuildContext context) {
    final child = Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            color: widget.color ?? Colors.transparent),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            Container(
                height: 108,
                padding: EdgeInsets.only(left: 16, right: 16),
                child: SliderTheme(
                    //自定义风格
                    data: SliderTheme.of(context).copyWith(

                        ///进度条滑块左边颜色
                        activeTrackColor: _UIColors.white,

                        ///进度条滑块右边颜色
                        inactiveTrackColor:
                            _UIColors.colorEBEDF0.withOpacity(0.5),

                        ///进度条形状,这边自定义两头显示圆角
                        trackShape: RoundSliderTrackShape(radius: 5),

                        ///滑块颜色
                        thumbColor: Colors.white,

                        ///滑块拖拽时外圈的颜色
                        overlayColor: Color.fromRGBO(51, 126, 255, 0.70),
                        overlayShape: RoundSliderOverlayShape(
                          ///可继承SliderComponentShape自定义形状
                          overlayRadius: 12, //滑块外圈大小
                        ),
                        thumbShape: RoundSliderThumbShape(
                          ///可继承SliderComponentShape自定义形状
                          disabledThumbRadius: 10,

                          ///禁用是滑块大小
                          enabledThumbRadius: 10,

                          ///滑块大小
                        ),
                        inactiveTickMarkColor: Colors.black,
                        tickMarkShape: RoundSliderTickMarkShape(
                          ///继承SliderTickMarkShape可自定义刻度形状
                          tickMarkRadius: 2.0, //刻度大小
                        ),
                        showValueIndicator: ShowValueIndicator.onlyForDiscrete,

                        ///气泡显示的形式
                        valueIndicatorColor: Colors.red,

                        ///气泡颜色
                        valueIndicatorShape: PaddleSliderValueIndicatorShape(),

                        ///气泡形状
                        valueIndicatorTextStyle: TextStyle(color: Colors.black),

                        ///气泡里值的风格
                        trackHeight: 4

                        ///进度条宽度

                        ),
                    child: Slider(
                      key: MeetingUIValueKeys.beautyLevelSlider,
                      value: _level.toDouble(),
                      min: 0,
                      max: 10,
                      // label: "等级:$value",
                      //             //气泡的值
                      //             divisions: 10,
                      //             //进度条上显示多少个刻度点
                      label: '$_level',
                      onChanged: (double newValue) {
                        setState(() {
                          _level = newValue.round();
                        });
                        widget.onChange(_level);
                      },
                    ))),
          ],
        ));
    return child;
  }

  @override
  void dispose() {
    if (widget.closeCallBack != null) {
      widget.closeCallBack!();
    }
    super.dispose();
  }
}
