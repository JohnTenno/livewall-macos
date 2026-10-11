import Foundation

/// JavaScript that emulates the parts of Wallpaper Engine's web API that pages commonly rely on,
/// so Workshop web wallpapers run without crashing and start with their default settings.
enum WallpaperEngineShim {
    /// Injected at document start: stub registration functions that WE pages call unguarded.
    static let stubs = """
    (() => {
      const noop = () => {};
      window.wallpaperRegisterAudioListener = window.wallpaperRegisterAudioListener || noop;
      window.wallpaperRegisterMediaStatusListener = window.wallpaperRegisterMediaStatusListener || noop;
      window.wallpaperRegisterMediaPropertiesListener = window.wallpaperRegisterMediaPropertiesListener || noop;
      window.wallpaperRegisterMediaThumbnailListener = window.wallpaperRegisterMediaThumbnailListener || noop;
      window.wallpaperRegisterMediaPlaybackListener = window.wallpaperRegisterMediaPlaybackListener || noop;
      window.wallpaperRegisterMediaTimelineListener = window.wallpaperRegisterMediaTimelineListener || noop;
      window.wallpaperRequestRandomFileForProperty = window.wallpaperRequestRandomFileForProperty || noop;
    })();
    """

    /// Injected at document end: hands the project's default property values to the page.
    static func applyProperties(_ propertiesJSON: String) -> String {
        """
        (() => {
          const props = \(propertiesJSON);
          const apply = () => {
            const listener = window.wallpaperPropertyListener;
            if (listener && typeof listener.applyUserProperties === 'function') {
              try { listener.applyUserProperties(props); } catch (e) { console.error(e); }
            }
            if (listener && typeof listener.setPaused === 'function') {
              window.addEventListener('livewall-pause', () => listener.setPaused(true));
              window.addEventListener('livewall-play', () => listener.setPaused(false));
            }
          };
          if (document.readyState === 'complete') { apply(); } else { window.addEventListener('load', apply); }
        })();
        """
    }
}
