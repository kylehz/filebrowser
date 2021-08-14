<template>
  <div>
    <div id="dplayer" class="play-root"></div>
  </div>
</template>

<script>
// import '../../node_modules/dplayer/dist/DPlayer.min.js';
import DPlayer from "dplayer";

export default {
  name: "optimizeVideo",
  data() {
    return {
      dp: null,
    };
  },
  methods: {
    onPlay() {
      this.dp.play();
    },
  },
  // 一定要在mounted中创建
  mounted() {
    this.dp = new DPlayer({
      // 配置参数
      container: document.getElementById("dplayer"),
      autoplay: true,
      theme: "#FADFA3",
      loop: true,
      lang: "zh-cn",
      preload: "auto",
      // logo: 'logo.png',
      volume: 1,
      video: {
        url: "http://img.ksbbs.com/asset/Mon_1605/25d705200a4eab4.mp4",
        pic: "dplayer.png",
        type: "auto",
      },
    });

    // 禁止右键下载视频
    document.oncontextmenu = new Function("event.returnValue=false;");
    document.onselectstart = new Function("event.returnValue=false;");

    // 修改循环播放显示
    document
      .getElementsByClassName("dplayer-setting-item dplayer-setting-loop")[0]
      .getElementsByClassName("dplayer-label")[0].innerText = "循环播放";
    // 修改倍速播放显示
    document
      .getElementsByClassName("dplayer-setting-item dplayer-setting-speed")[0]
      .getElementsByClassName("dplayer-label")[0].innerText = "播放倍速";
  },
};
</script>

<style scoped>
.play-root {
  width: 770px;
  height: 420px;
  background-color: coral;
  margin: 0 auto;
}

/* 在浏览器找到对应的class名称。然后通过穿透对样式进行更改 */

/* 禁止循环播放显示 */
/* .paly-root >>> .dplayer-setting-loop {
    background-color: cyan;
    display: none;
  } */

/* 禁止出现快进多少秒提示 */
/* .play-root /deep/ .dplayer-notice {
    display: none;
  } */

/* 禁止右键自定义列表 */
/* .play-root /deep/ .dplayer-menu-show{
     display: none;
  } */
</style>
