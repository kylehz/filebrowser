<template>
  <div
    id="previewer"
    @mousemove="toggleNavigation"
    @touchstart="toggleNavigation"
  >
    <header-bar>
      <action icon="close" :label="$t('buttons.close')" @action="close()" />
      <title>{{ name }}</title>
      <action
        :disabled="loading"
        v-if="isResizeEnabled && req.type === 'image'"
        :icon="fullSize ? 'photo_size_select_large' : 'hd'"
        @action="toggleSize"
      />

      <template #actions>
        <action
          :disabled="loading"
          v-if="user.perm.rename"
          icon="mode_edit"
          :label="$t('buttons.rename')"
          show="rename"
        />
        <action
          :disabled="loading"
          v-if="user.perm.delete"
          icon="delete"
          :label="$t('buttons.delete')"
          @action="deleteFile"
          id="delete-button"
        />
        <action
          :disabled="loading"
          v-if="user.perm.download"
          icon="file_download"
          :label="$t('buttons.download')"
          @action="download"
        />
        <action
          :disabled="loading"
          icon="info"
          :label="$t('buttons.info')"
          show="info"
        />
      </template>
    </header-bar>

    <div class="loading delayed" v-if="loading">
      <div class="spinner">
        <div class="bounce1"></div>
        <div class="bounce2"></div>
        <div class="bounce3"></div>
      </div>
    </div>
    <template v-else>
      <div class="preview" style="width: 100%; height: 100%; margin: 0 auto">
        <ExtendedImage v-if="req.type == 'image'" :src="raw"></ExtendedImage>
        <!-- <audio
          v-else-if="req.type == 'audio'"
          ref="player"
          :src="raw"
          controls
          :autoplay="autoPlay"
          @play="autoPlay = true"
        ></audio> -->
        <d-player
          v-else-if="req.type == 'video' || req.type == 'audio'"
          style="width: 100%; height: 100%; margin: 0 auto"
          ref="player"
          :options="videoOptions"
        >
        </d-player>

        <!-- <video
          v-else-if="req.type == 'video'"
          ref="player"
          :src="raw"
          controls
          :autoplay="autoPlay"
          @play="autoPlay = true"
        >
          <track
            kind="captions"
            v-for="(sub, index) in subtitles"
            :key="index"
            :src="sub"
            :label="'Subtitle ' + index"
            :default="index === 0"
          />
          Sorry, your browser doesn't support embedded videos, but don't worry,
          you can <a :href="downloadUrl">download it</a>
          and watch it with your favorite video player!
        </video> -->
        <object
          v-else-if="req.extension.toLowerCase() == '.pdf'"
          class="pdf"
          :data="raw"
        ></object>
        <a v-else-if="req.type == 'blob'" :href="downloadUrl">
          <h2 class="message">
            {{ $t("buttons.download") }}
            <i class="material-icons">file_download</i>
          </h2>
        </a>
      </div>
    </template>

    <button
      @click="prev"
      @mouseover="hoverNav = true"
      @mouseleave="hoverNav = false"
      :class="{ hidden: !hasPrevious || !showNav }"
      :aria-label="$t('buttons.previous')"
      :title="$t('buttons.previous')"
    >
      <i class="material-icons">chevron_left</i>
    </button>
    <button
      @click="next"
      @mouseover="hoverNav = true"
      @mouseleave="hoverNav = false"
      :class="{ hidden: !hasNext || !showNav }"
      :aria-label="$t('buttons.next')"
      :title="$t('buttons.next')"
    >
      <i class="material-icons">chevron_right</i>
    </button>
  </div>
</template>

<script>
import { mapState } from "vuex";
import { files as api } from "@/api";
import { baseURL, resizePreview } from "@/utils/constants";
import url from "@/utils/url";
import throttle from "lodash.throttle";

import HeaderBar from "@/components/header/HeaderBar";
import Action from "@/components/header/Action";
import ExtendedImage from "@/components/files/ExtendedImage";

const mediaTypes = ["image", "video", "audio", "blob"];

export default {
  name: "preview",
  components: {
    HeaderBar,
    Action,
    ExtendedImage,
  },
  data: function () {
    return {
      previousLink: "",
      nextLink: "",
      listing: null,
      name: "",
      subtitles: [],
      fullSize: false,
      showNav: true,
      navTimeout: null,
      hoverNav: false,
      autoPlay: false,
      source: "",
      player: null,
    };
  },
  computed: {
    ...mapState(["req", "user", "oldReq", "jwt", "loading", "show"]),
    hasPrevious() {
      return this.previousLink !== "";
    },
    hasNext() {
      return this.nextLink !== "";
    },
    downloadUrl() {
      console.log("startsWith:", this.req.url);
      if (this.req.url.startsWith("/share/")) {
        let queryArg = "";
        if (this.token !== "") {
          queryArg = `?token=${this.token}`;
        }
        const path = this.$route.path.split("/").splice(2).join("/");
        return `${baseURL}/api/public/dl/${path}${queryArg}`;
      }
      return `${baseURL}/api/raw${url.encodePath(this.req.path)}?auth=${
        this.jwt
      }`;
    },
    pubfullLink() {
      return window.location.origin + this.link;
    },
    previewUrl() {
      if (this.req.url.startsWith("/share/")) {
        let queryArg = "";
        if (this.token !== "") {
          queryArg = `?token=${this.token}`;
        }

        const path = this.$route.path.split("/").splice(2).join("/");
        return `${baseURL}/api/public/dl/${path}${queryArg}`;
      }
      // reload the image when the file is replaced
      const key = Date.parse(this.req.modified);

      if (this.req.type === "image" && !this.fullSize) {
        return `${baseURL}/api/preview/big${url.encodePath(
          this.req.path
        )}?k=${key}`;
      }
      return `${baseURL}/api/raw${url.encodePath(this.req.path)}?k=${key}`;
    },
    raw() {
      return `${this.previewUrl}&inline=true`;
    },
    showMore() {
      return this.$store.state.show === "more";
    },
    isResizeEnabled() {
      return resizePreview;
    },
    videoOptions() {
      return {
        container: document.getElementById("dplayer"), //播放器容器
        mutex: false, //  防止同时播放多个用户，在该用户开始播放时暂停其他用户
        theme: "#b7daff", // 风格颜色，例如播放条，音量条的颜色
        loop: false, // 是否自动循环
        lang: "zh-cn", // 语言，'en', 'zh-cn', 'zh-tw'
        // screenshot: true, // 是否允许截图（按钮），点击可以自动将截图下载到本地
        hotkey: true, // 是否支持热键，调节音量，播放，暂停等
        preload: "none", // 自动预加载
        volume: 1, // 初始化音量
        playbackSpeed: [0.5, 0.75, 1, 1.25, 1.5, 2, 3], //可选的播放速度，可自定义
        // logo:
        //   "https://qczh-1252727916.cos.ap-nanjing.myqcloud.com/pic/273658f508d04d488414fd2b84c9f923.png", // 在视频左角上打一个logo
        video: {
          url: `${this.previewUrl}`,
        },
        highlight: [
          {
            text: "10M",
            time: 6,
          },
          {
            text: "20M",
            time: 12,
          },
        ],
      };
    },
  },
  watch: {
    $route: function () {
      this.updatePreview();
      this.toggleNavigation();
    },
  },
  async mounted() {
    // console.log(this.req.type);
    // window.addEventListener("keydown", this.key);
    this.listing = this.oldReq.items;
    this.updatePreview();
    this.player = this.$refs.player.dp;
    this.player.play();
  },
  // beforeDestroy() {
  //   window.removeEventListener("keydown", this.key);
  // },
  methods: {
    deleteFile() {
      this.$store.commit("showHover", {
        prompt: "delete",
        confirm: () => {
          this.listing = this.listing.filter((item) => item.name !== this.name);

          if (this.hasNext) {
            this.next();
          } else if (!this.hasPrevious && !this.hasNext) {
            this.close();
          } else {
            this.prev();
          }
        },
      });
    },
    prev() {
      this.hoverNav = false;
      this.$router.push({ path: this.previousLink });
    },
    next() {
      this.hoverNav = false;
      this.$router.push({ path: this.nextLink });
    },
    // key(event) {
    //   if (this.show !== null) {
    //     return;
    //   }

    //   if (event.which === 13 || event.which === 39) {
    //     // right arrow
    //     if (this.hasNext) this.next();
    //   } else if (event.which === 37) {
    //     // left arrow
    //     if (this.hasPrevious) this.prev();
    //   } else if (event.which === 27) {
    //     // esc
    //     this.close();
    //   }
    // },
    async updatePreview() {
      if (
        this.$refs.player &&
        this.$refs.player.paused &&
        !this.$refs.player.ended
      ) {
        this.autoPlay = true;
      }

      if (this.req.subtitles) {
        this.subtitles = this.req.subtitles.map(
          // (sub) => `${baseURL}/api/raw${sub}?inline=true`
          (sub) => `${baseURL}/api/raw${sub}`
        );
      }

      // let dirs = this.$route.fullPath.split("/");
      // this.name = decodeURIComponent(dirs[dirs.length - 1]);
      this.name = document.title;

      if (!this.listing) {
        try {
          const path = url.removeLastDir(this.$route.path);
          const res = await api.fetch(path);
          this.listing = res.items;
        } catch (e) {
          console.log("err:", e);
          // this.$showError(e);
        }
      }

      this.previousLink = "";
      this.nextLink = "";

      if (this.listing) {
        for (let i = 0; i < this.listing.length; i++) {
          if (this.listing[i].name !== this.name) {
            continue;
          }

          for (let j = i - 1; j >= 0; j--) {
            if (mediaTypes.includes(this.listing[j].type)) {
              this.previousLink = this.listing[j].url;
              break;
            }
          }

          for (let j = i + 1; j < this.listing.length; j++) {
            if (mediaTypes.includes(this.listing[j].type)) {
              this.nextLink = this.listing[j].url;
              break;
            }
          }
        }
        return;
      }
    },
    openMore() {
      this.$store.commit("showHover", "more");
    },
    resetPrompts() {
      this.$store.commit("closeHovers");
    },
    toggleSize() {
      this.fullSize = !this.fullSize;
    },
    toggleNavigation: throttle(function () {
      this.showNav = true;

      if (this.navTimeout) {
        clearTimeout(this.navTimeout);
      }

      this.navTimeout = setTimeout(() => {
        this.showNav = false || this.hoverNav;
        this.navTimeout = null;
      }, 1500);
    }, 500),
    close() {
      this.$store.commit("updateRequest", {});

      let uri = url.removeLastDir(this.$route.path) + "/";
      this.$router.push({ path: uri });
    },
    download() {
      window.open(this.downloadUrl);
    },
  },
};
</script>
