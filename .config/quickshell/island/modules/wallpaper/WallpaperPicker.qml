import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Qt.labs.folderlistmodel
import QtMultimedia
import Quickshell
import Quickshell.Io
import QtQuick.Dialogs
import qs.services

Item {
    Settings {
        id: settings
    }

    FileDialog {
        id: fileDialog
        title: "Select Wallpaper"
        nameFilters: ["Images & Videos (*.png *.jpg *.jpeg *.webp *.gif *.mp4 *.mkv *.mov *.webm)"]
        fileMode: FileDialog.OpenFiles

        onAccepted: {
            for (let i = 0; i < selectedFiles.length; i++) {
                window.importWallpaper(selectedFiles[i])
            }
            window.reloadFolder()
        }
    }

    id: window
    width: Screen.width
    // The picker used to be a fresh process per open, so "visible" was
    // always just true and closing meant killing the whole process.
    // It's permanent now -- GlobalState.wallpaperPickerOpen is the actual
    // open/close switch, driving both this and the outer PanelWindow in
    // shell.qml, and onVisibleChanged below already does the state reset
    // an old fresh process got for free.
    visible: GlobalState.wallpaperPickerOpen

    // --- Responsive Scaling Logic ---
    Scaler {
        id: scaler
        currentWidth: Screen.width
    }

    function s(val) {
        return scaler.s(val);
    }

    function anim(ms) {
        return settings.uiAnimationsEnabled ? Math.max(0, Math.round(ms * settings.uiAnimationScale)) : 0;
    }

    readonly property var safeTransitions: ["fade", "wipe", "wave", "grow", "center", "outer", "any"]

    function normalizeTransition(name) {
        const t = String(name || "").trim().toLowerCase();
        if (t === "" || t === "random") return "random";
        return window.safeTransitions.indexOf(t) !== -1 ? t : "fade";
    }

    function pickTransition() {
        const chosen = normalizeTransition(settings.wallpaperTransitionType);
        if (chosen !== "random") {
            return chosen;
        }
        return window.safeTransitions[Math.floor(Math.random() * window.safeTransitions.length)];
    }

    function requestClose() {
        closeAfterApply.restart();
    }

    Timer {
        id: closeAfterApply
        interval: settings.closeDelayMs
        repeat: false
        onTriggered: GlobalState.wallpaperPickerOpen = false
    }

    MatugenColors { id: _theme; polling: settings.enableDynamicColors }

    // -------------------------------------------------------------------------
    // PROPERTIES & IPC RECEIVER
    // -------------------------------------------------------------------------
    property string widgetArg: ""
    property string targetWallName: ""
    property bool initialFocusSet: false
    property int visibleItemCount: -1
    property int scrollAccum: 0
    property real scrollThreshold: window.s(300) 

    // Filter System Properties
    property string currentFilter: "All"
    property string _lastFilter: "All"
    property string searchQuery: ""
    property bool isOnlineSearch: false
    property bool isSearchPaused: false
    property bool hasSearched: false 
    property var colorMap: ({})
    property int cacheVersion: 0 
    
    // Download and Status Tracking Properties
    property bool isDownloadingWallpaper: false
    property string currentDownloadName: ""
    
    // STRICT ARCHITECTURAL LOCK
    property bool isApplying: false 
    
    // Reactive Status Properties
    property bool isStartup: localFolderModel.status === FolderListModel.Loading || srcModel.status === FolderListModel.Loading
    property bool isReady: visible && localFolderModel.status === FolderListModel.Ready
    property bool isSearchActive: false
    
    // Memory Properties for Search
    property string lastSearchName: ""
    property bool isModelChanging: false
    property bool searchIndexRestored: false
    
    // Lock scrolling/interaction while actively streaming search results.
    property bool isScrollingBlocked: false
    property bool jumpToLastOnFilterChange: false

    readonly property var filterData: [
        { name: "All", hex: "", label: "All" },
        { name: "Video", hex: "", label: "Vid" },
        { name: "Red", hex: "#FF4500", label: "" },
        { name: "Orange", hex: "#FFA500", label: "" },
        { name: "Yellow", hex: "#FFD700", label: "" },
        { name: "Green", hex: "#32CD32", label: "" },
        { name: "Blue", hex: "#1E90FF", label: "" },
        { name: "Purple", hex: "#8A2BE2", label: "" },
        { name: "Pink", hex: "#FF69B4", label: "" },
        { name: "Monochrome", hex: "#A9A9A9", label: "" },
        { name: "Search", hex: "", label: "Search" } 
    ]

    // -------------------------------------------------------------------------
    // GLOBAL ACTION: APPLY WALLPAPER
    // -------------------------------------------------------------------------
    function applyWallpaper(safeFileName, isVideo) {
        if (!safeFileName || window.isApplying) return;

        // 1. STRICT LOCK: Instantly block all further mouse and keyboard input
        window.isApplying = true;

        window.targetWallName = safeFileName
        let cleanName = window.getCleanName(safeFileName)

        const escapeBash = (str) => String(str).replace(/(["\\$`])/g, '\\$1');
        // Bookkeeping (state file, notify-send, and --
        // only for the matugen theme -- full color regeneration) used to
        // run in wallpaper-selector.sh/wallpapers-set-matugen.sh after the
        // old standalone picker process exited, reading its pick back from
        // /tmp/qs_last_wallpaper. The picker never exits now, so this
        // just runs inline, right alongside the awww/mpvpaper call below.
        const postApply = (path) => `wallpaper-apply-post.sh "${escapeBash(path)}" >> /tmp/qs_apply.log 2>&1 &`;

        if (window.currentFilter === "Search" && window.hasSearched) {
            let alreadyExists = window.isDownloaded(safeFileName);
            let destFile = window.srcDir + "/" + safeFileName;
            let finalThumb = decodeURIComponent(window.thumbDir.replace("file://", "")) + "/" + safeFileName;
            let tempThumb = decodeURIComponent(window.searchDir.replace("file://", "")) + "/" + safeFileName;
            let mapFile = Quickshell.env("HOME") + "/.cache/wallpaper_picker/search_map.txt";
            const randomTransition = window.transitions[Math.floor(Math.random() * window.transitions.length)];

            if (alreadyExists) {
                const applyScript = `
                    (
                        export DEST_FILE="${escapeBash(destFile)}"
                        export RANDOM_TRANSITION="${escapeBash(window.normalizeTransition(randomTransition))}"
                        export TRANSITION_DURATION="${Number(settings.wallpaperTransitionDuration).toFixed(2)}"
                        export TRANSITION_FPS="${Math.max(1, Number(settings.wallpaperTransitionFps))}"

                        pkill mpvpaper || true
                        ${postApply(destFile)}

                        # DETERMINISTIC LOOP: Force wallpaper apply to succeed.
                        # It will poll every 50ms up to 20 times until the compositor accepts the frame.
                        for i in {1..20}; do
                            if awww img --transition-type "$RANDOM_TRANSITION" --transition-duration "$TRANSITION_DURATION" --transition-fps "$TRANSITION_FPS" "$DEST_FILE" >/dev/null 2>&1; then
                                break
                            fi
                            if awww img --transition-type fade --transition-duration "$TRANSITION_DURATION" --transition-fps "$TRANSITION_FPS" "$DEST_FILE" >/dev/null 2>&1; then
                                break
                            fi
                            sleep 0.05
                        done
                    ) > /tmp/qs_apply.log 2>&1 & disown
                `;
                Quickshell.execDetached(["bash", "-c", applyScript]);
                window.requestClose();
            } else {
                window.isDownloadingWallpaper = true;
                window.currentDownloadName = safeFileName;

                const downloadScript = `
                    export SAFE_NAME="${escapeBash(safeFileName)}"
                    export DEST_FILE="${escapeBash(destFile)}"
                    export FINAL_THUMB="${escapeBash(finalThumb)}"
                    export TEMP_THUMB="${escapeBash(tempThumb)}"
                    export MAP_FILE="${escapeBash(mapFile)}"

                    (
                        URL=$(awk -F'|' -v fname="$SAFE_NAME" '$1 == fname {print $2; exit}' "$MAP_FILE")
                        if [ -n "$URL" ]; then
                            curl -s -L -A "Mozilla/5.0" "$URL" -o "$DEST_FILE.tmp"

                            if file "$DEST_FILE.tmp" | grep -iq "webp"; then
                                magick "$DEST_FILE.tmp" "$DEST_FILE"
                                rm -f "$DEST_FILE.tmp"
                            else
                                mv "$DEST_FILE.tmp" "$DEST_FILE"
                            fi

                            cp "$TEMP_THUMB" "$FINAL_THUMB"
                            magick "$DEST_FILE" -resize x420 -quality 70 "$FINAL_THUMB" || true

                                pkill mpvpaper || true
                            ${postApply(destFile)}

                            # DETERMINISTIC LOOP
                            for i in {1..20}; do
                                if awww img --transition-type "$RANDOM_TRANSITION" --transition-duration "$TRANSITION_DURATION" --transition-fps "$TRANSITION_FPS" "$DEST_FILE" >/dev/null 2>&1; then
                                    break
                                fi
                                if awww img --transition-type fade --transition-duration "$TRANSITION_DURATION" --transition-fps "$TRANSITION_FPS" "$DEST_FILE" >/dev/null 2>&1; then
                                    break
                                fi
                                sleep 0.05
                            done
                        fi
                    ) > /tmp/qs_apply.log 2>&1 & disown
                `;
                Quickshell.execDetached(["bash", "-c", downloadScript]);
                window.requestClose();
            }
            return;
        }

        const originalFile = window.srcDir + "/" + String(safeFileName).replace(/^thumb_/, "")
        const thumbFile = settings.thumbDir + "/" + safeFileName

        let wallpaperCmd = ""

        const escOriginal = escapeBash(originalFile);
        const escThumb = escapeBash(thumbFile);

        if (isVideo) {
            wallpaperCmd = `mpvpaper -o 'loop --no-audio --hwdec=auto --profile=high-quality --video-sync=display-resample --interpolation --tscale=oversample' '*' "$WALL_FILE"`
        } else {
            wallpaperCmd = `
                TRANSITION="${window.pickTransition()}"
                DURATION="${Number(settings.wallpaperTransitionDuration).toFixed(2)}"
                FPS="${Math.max(1, Number(settings.wallpaperTransitionFps))}"
                if ! awww img --transition-type "$TRANSITION" --transition-duration "$DURATION" --transition-fps "$FPS" "$WALL_FILE" >/dev/null 2>&1; then
                    awww img --transition-type fade --transition-duration "$DURATION" --transition-fps "$FPS" "$WALL_FILE"
                fi
            `
        }

        const fullScript = `
            (
                export WALL_FILE="${escOriginal}"
                export THUMB_FILE="${escThumb}"

                echo "WALL_FILE=$WALL_FILE" > /tmp/qs_apply.log
                ${postApply(originalFile)}

                if [ "${isVideo}" = "true" ]; then
                    pkill mpvpaper || true
                    ${wallpaperCmd}
                else
                    pkill mpvpaper || true
                    ${wallpaperCmd}
                fi
            ) >> /tmp/qs_apply.log 2>&1 & disown
        `
        Quickshell.execDetached(["bash", "-c", fullScript])
        window.requestClose()
    }

    // -------------------------------------------------------------------------
    // PERSISTENT SETTINGS
    // -------------------------------------------------------------------------
    QtObject {
        id: searchState
        property string query: ""
        property bool searched: false
        property string lastName: ""
    }

    // -------------------------------------------------------------------------
    // VISIBILITY LOGIC
    // -------------------------------------------------------------------------
    onVisibleChanged: {
        if (!visible) {
            window.initialFocusSet = false;
            window.searchIndexRestored = false;
            window.isApplying = false;
            if (window.hasSearched) {
                window.isSearchPaused = true;
            }
            // GlobalState.wallpaperPickerOpen = false intentionally not
            // called from here: closing is driven exclusively by the
            // closeAfterApply timer and the Escape shortcut, not by
            // visibility changes (which can fire if another window covers
            // us) -- this handler only resets state, it never decides
            // open/closed itself.
        } else {
            window.onPickerOpened();
        }
    }

    // Runs every time the picker is reopened, not just on first creation.
    // The standalone app got this for free from Component.onCompleted
    // (every open was a fresh process); as a permanent component, focus,
    // the color-filter reset and thumbnail generation all have to be
    // re-triggered explicitly here instead.
    function onPickerOpened() {
        window.generateThumbs();

        if (window.hasSearched) {
            window.trySearchFocus();
        } else {
            window.tryFocus();
        }
        view.forceActiveFocus();

        // Reset any stale color/search filter left over from a previous
        // (possibly matugen) session -- enableColorFiltering is reactive
        // to the theme, so this can legitimately flip between opens.
        if (!settings.enableColorFiltering) {
            window.currentFilter = "All";
        } else {
            window.processMarkers();
            window.triggerColorExtraction();
        }
    }
    // -------------------------------------------------------------------------
    property bool isLoading: localFolderModel.status === FolderListModel.Loading || 
                             srcModel.status === FolderListModel.Loading

    property bool showSpinner: window.isDownloadingWallpaper || 
                               (window.currentFilter !== "Search" && window.isLoading)

    property string currentNotification: {
        if (window.isDownloadingWallpaper) return "Downloading wallpaper...";

        if (window.currentFilter === "Search") {
            if (!window.hasSearched) return "Type to search local wallpapers...";
            if (window.visibleItemCount === 0) return "No local matches";
            return "Local search";
        }

        if (isLoading) return "Generating thumbnails...";
        if (window.visibleItemCount === 0) return "No wallpapers found";

        if (window.currentFilter === "All") return "";
        if (window.currentFilter === "Video") return "Videos";

        return window.currentFilter;
    }

    // Block the notification flag during initial load to stop UI shifting
    property bool showNotification: !window.isStartup && currentNotification !== ""

    function getCleanName(name) {
        if (!name) return "";
        let clean = String(name);
        return clean.startsWith("000_") ? clean.substring(4) : clean;
    }

    function checkIfVideo(name) {
        if (!name) return false;
        let lower = String(name).toLowerCase();
        return lower.endsWith(".mp4") || lower.endsWith(".mkv") || lower.endsWith(".mov") || lower.endsWith(".webm") || lower.startsWith("000_");
    }

    function importWallpaper(fileUrl) {
        let src = decodeURIComponent(fileUrl.toString().replace("file://", ""));
        let destDir = window.srcDir;
        const escapeBash = (str) => String(str).replace(/(["\\$`])/g, '\\$1');
        let cmd = `cp "${escapeBash(src)}" "${escapeBash(destDir)}/"`;
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    // Clearing `folder` first is what actually forces a re-scan (assigning
    // the same path back is a no-op). But a plain assignment also destroys
    // the declarative binding these models were declared with -- and those
    // bindings are the ONLY thing that repoints the grid when the theme
    // changes underneath it. Once broken, the picker stays stuck on
    // whichever theme's folder it was showing for the rest of the session,
    // which is permanent now that the picker never exits. Reassigning
    // through Qt.binding() restores the live binding after the re-scan.
    function reloadFolder() {
        localFolderModel.folder = "";
        localFolderModel.folder = Qt.binding(() => window.thumbDir);
        srcModel.folder = "";
        srcModel.folder = Qt.binding(() => "file://" + window.srcDir);
    }

    // Build the active theme's thumbnails.
    //
    // Tracked as a real Process rather than execDetached specifically so
    // the folder can be re-scanned when it finishes. thumbDir is
    // ~/.cache/wallpaper_picker/thumbs_<theme>, so switching to a theme
    // whose thumbnails have never been built points localFolderModel at a
    // directory that does not exist yet -- and a FolderListModel assigned
    // a non-existent path settles into Ready with count 0 and NEVER
    // recovers once the path appears. There is no watcher on a directory
    // that was never there, so generate-thumbs.sh would fill the cache
    // and the grid would stay empty for the rest of the session. Forcing
    // a re-scan after generation is what actually makes the wallpapers
    // show up on the first open under a new theme.
    Process {
        id: thumbGen

        // Set from the script's TOTAL line. Zero means it found nothing to
        // do and exited silently, which is the usual case.
        property int thumbTotal: 0
        property int thumbDone: 0

        command: ["bash", "-c", "generate-thumbs.sh '" + settings.wallpaperDir + "' '" + settings.thumbDir + "'"]

        onRunningChanged: if (running) {
            thumbGen.thumbTotal = 0;
            thumbGen.thumbDone = 0;
        }

        // Building a theme's cache for the first time is a real wait --
        // 169 wallpapers on the matugen theme -- during which the grid is
        // empty and nothing explains why. The script counts the missing
        // thumbnails up front so this can be a genuine fraction rather
        // than a spinner.
        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                const parts = line.trim().split(" ");
                if (parts[0] === "TOTAL") {
                    thumbGen.thumbTotal = parseInt(parts[1], 10) || 0;
                } else if (parts[0] === "PROGRESS") {
                    thumbGen.thumbDone = parseInt(parts[1], 10) || 0;
                } else {
                    return;
                }

                if (thumbGen.thumbTotal <= 0)
                    return;

                Activities.push({
                    id: "thumbs",
                    icon: "image",
                    title: "Thumbnails",
                    subtitle: Colors.themeName,
                    value: `${thumbGen.thumbDone}/${thumbGen.thumbTotal}`,
                    progress: thumbGen.thumbDone / thumbGen.thumbTotal
                });
            }
        }

        onExited: {
            Activities.remove("thumbs");

            // Only when the scan came up empty -- that's the broken case.
            // Where the directory did already exist, FolderListModel's own
            // watcher picks new files up by itself, and re-assigning
            // `folder` there would clear the proxy model and drop the
            // focused item (see syncLocalModel) for no reason.
            if (localFolderModel.count === 0)
                window.reloadFolder();
        }
    }

    function generateThumbs() {
        if (!thumbGen.running)
            thumbGen.running = true;
    }


    // A theme switch repoints thumbDir at a different cache directory. If
    // it happens while the picker is already open, no onPickerOpened fires
    // to build that directory -- which is how a theme ends up with no
    // thumbs_<theme> cache at all, and the grid goes empty the moment the
    // theme changes under it.
    Connections {
        target: settings
        function onThumbDirChanged() {
            if (window.visible)
                window.generateThumbs();
        }
    }

    function isDownloaded(name) {
        if (!name) return false;
        for (let i = 0; i < srcModel.count; i++) {
            if (srcModel.get(i, "fileName") === name) return true;
        }
        return false;
    }

    onWidgetArgChanged: {
        if (widgetArg !== "") {
            targetWallName = widgetArg;
            initialFocusSet = false; 
            tryFocus();
        }
    }

    function executeFocusRestore(targetIndex, isSearchRestore, requirePositioning) {
        let targetModel = window.getModelForFilter(window.currentFilter);
        
        if (targetIndex !== -1 && targetIndex < targetModel.count) {
            window.isModelChanging = true;
            
            if (requirePositioning) {
                view.forceLayout();
                view.positionViewAtIndex(targetIndex, ListView.Center);
            }
            
            view.currentIndex = targetIndex;
            
            if (isSearchRestore) {
                window.searchIndexRestored = true;
            }
            
            window.isModelChanging = false;
            window.initialFocusSet = true;
        } else if (isSearchRestore) {
            window.searchIndexRestored = true;
        }
    }

    function tryFocus() {
        if (initialFocusSet) return;
        // Don't lock in initial focus/positioning off a partial model.
        // FolderListModel populates incrementally (countChanged can fire
        // many times as files are discovered before status flips to
        // Ready) -- centering on whichever file the OS happened to
        // return first, then never re-running because initialFocusSet is
        // now permanently true, is what caused the "first keyboard arrow
        // press" bug: the ListView is focusable and responds to arrow
        // keys even while still invisible (opacity 0 pre-isReady), so
        // navigating during that partial-load window moved currentIndex
        // against a model that was about to grow substantially further
        // underneath it.
        if (localFolderModel.status !== FolderListModel.Ready) return;

        if (localProxyModel.count > 0) {
            let foundIndex = -1;
            let cleanTarget = window.getCleanName(targetWallName);

            if (cleanTarget !== "") {
                for (let i = 0; i < localProxyModel.count; i++) {
                    let fname = localProxyModel.get(i).fileName || "";
                    if (window.getCleanName(fname) === cleanTarget) {
                        foundIndex = i;
                        break;
                    }
                }
            }

            let finalIndex = foundIndex !== -1 ? foundIndex : 0;
            window.executeFocusRestore(finalIndex, false, true);
        }
    }
    
    function trySearchFocus() {
        if (window.searchIndexRestored || localProxyModel.count === 0) return;

        if (window.lastSearchName === "") {
             window.searchIndexRestored = true;
             return;
        }

        for (let i = 0; i < localProxyModel.count; i++) {
            let fname = localProxyModel.get(i).fileName || "";
            if (fname === window.lastSearchName) {
                window.executeFocusRestore(i, true, true);
                return;
            }
        }

        window.searchIndexRestored = true;
    }

    function getModelForFilter(filter) {
        // Both filter modes use the same model; kept for callsite readability.
        return localProxyModel;
    }

    function updateVisibleCount() {
        let targetModel = window.getModelForFilter(window.currentFilter);
        
        if (!targetModel || targetModel.count === 0) {
            window.visibleItemCount = 0;
            return;
        }
        let count = 0;
        for (let i = 0; i < targetModel.count; i++) {
            let fname = targetModel.get(i).fileName || "";
            let isVid = window.checkIfVideo(fname);
            if (checkItemMatchesFilter(fname, isVid, window.cacheVersion, window.currentFilter)) {
                count++;
            }
        }
        window.visibleItemCount = count;
    }

    function triggerLocalSearch() {
        if (searchInput.text.trim() === "") return;

        window.isModelChanging = true;

        window.lastSearchName = "";
        searchState.lastName = "";

        window.currentFilter = "Search";
        window.searchIndexRestored = true;
        window.isOnlineSearch = false;
        window.hasSearched = true;
        window.isSearchPaused = true;
        window.searchQuery = searchInput.text.trim().toLowerCase();
        searchState.searched = true;
        searchState.query = window.searchQuery;

        view.currentIndex = 0;
        view.positionViewAtIndex(0, ListView.Center);

        window.isModelChanging = false;

        window.updateVisibleCount();
        window.applyFilters(true);

        searchInput.focus = false;
        view.forceActiveFocus();
    }

    readonly property string homeDir: "file://" + Quickshell.env("HOME")
    readonly property string thumbDir: "file://" + settings.thumbDir
    readonly property string searchDir: homeDir + "/.cache/wallpaper_picker/search_thumbs"
    readonly property string srcDir: settings.wallpaperDir

    readonly property var defaultTransitions: window.safeTransitions
    readonly property var transitions: settings.wallpaperTransitionType === "random" ? window.defaultTransitions : [window.normalizeTransition(settings.wallpaperTransitionType)]

    readonly property real itemWidth: window.s(400)
    readonly property real itemHeight: window.s(420)
    readonly property real borderWidth: window.s(3)
    readonly property real spacing: window.s(10)
    readonly property real skewFactor: -0.35

    Timer {
        id: scrollThrottle
        interval: settings.scrollThrottleMs 
    }

    property bool isFilterAnimating: false
    Timer {
        id: filterAnimationTimer
        interval: settings.filterAnimationMs
        onTriggered: window.isFilterAnimating = false
    }

    property bool isItemAnimating: false
    Timer {
        id: itemAnimationTimer
        interval: settings.itemAnimationMs
        onTriggered: window.isItemAnimating = false
    }

    // -------------------------------------------------------------------------
    // COLOR FILTERING MATH & NATIVE FILE SYSTEM CACHE
    // -------------------------------------------------------------------------
    function getHexBucket(hexStr) {
        if (!hexStr) return "Monochrome";
        
        hexStr = String(hexStr).trim().replace(/#/g, '');
        if (hexStr.length > 6) hexStr = hexStr.substring(0, 6);
        if (hexStr.length !== 6) return "Monochrome";

        let r = parseInt(hexStr.substring(0,2), 16) / 255;
        let g = parseInt(hexStr.substring(2,4), 16) / 255;
        let b = parseInt(hexStr.substring(4,6), 16) / 255;

        if (isNaN(r) || isNaN(g) || isNaN(b)) return "Monochrome";

        let max = Math.max(r, g, b), min = Math.min(r, g, b);
        let d = max - min;
        
        let h = 0;
        let s = max === 0 ? 0 : d / max;
        let v = max;

        if (max !== min) {
            if (max === r) {
                h = (g - b) / d + (g < b ? 6 : 0);
            } else if (max === g) {
                h = (b - r) / d + 2;
            } else {
                h = (r - g) / d + 4;
            }
            h /= 6;
        }
        h = h * 360; 

        if (s < 0.05 || v < 0.08) return "Monochrome";

        if (h >= 345 || h < 15) return "Red";
        if (h >= 15 && h < 45) return "Orange";
        if (h >= 45 && h < 75) return "Yellow";
        if (h >= 75 && h < 165) return "Green";
        if (h >= 165 && h < 260) return "Blue";
        if (h >= 260 && h < 315) return "Purple";
        if (h >= 315 && h < 345) return "Pink";

        return "Monochrome";
    }

    function checkItemMatchesFilter(fileName, isVid, cv, filter) {
        const cleanName = window.getCleanName(fileName).toLowerCase();
        const q = (window.searchQuery || "").trim().toLowerCase();

        if (q !== "" && !cleanName.includes(q)) return false;

        if (filter === "Search") return true;
        if (filter === "All") return true;
        if (filter === "Video") return isVid;

        let hexColor = window.colorMap[String(fileName)];
        if (!hexColor) return filter === "Monochrome";

        return window.getHexBucket(hexColor) === filter;
    }

    FolderListModel {
        id: markerModel
        folder: "file://" + Quickshell.env("HOME") + "/.cache/wallpaper_picker/colors_markers"
        showDirs: false
        nameFilters: ["*_HEX_*"]
        
        onCountChanged: window.processMarkers()
        onStatusChanged: {
            if (status === FolderListModel.Ready) window.processMarkers()
        }
    }

    FolderListModel {
        id: srcModel
        folder: "file://" + window.srcDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false
        
        onCountChanged: {
            if (window.isDownloadingWallpaper && window.isDownloaded(window.currentDownloadName)) {
                window.isDownloadingWallpaper = false;
            }
        }
    }

    function processMarkers() {
        let newMap = {};
        for (let i = 0; i < markerModel.count; i++) {
            let markerName = markerModel.get(i, "fileName") || "";
            if (!markerName) continue;
            
            let splitIdx = markerName.lastIndexOf("_HEX_");
            if (splitIdx !== -1) {
                let fName = markerName.substring(0, splitIdx);
                let hexCode = markerName.substring(splitIdx + 5);
                newMap[fName] = "#" + hexCode;
            }
        }
        window.colorMap = newMap;
        window.cacheVersion++; 
        window.updateVisibleCount();
    }

    function triggerColorExtraction() {
        const extractScript = `
            COLOR_DIR="$HOME/.cache/wallpaper_picker/colors_markers"
            # Must be the SAME directory the grid is showing, i.e.
            # settings.thumbDir (~/.cache/wallpaper_picker/thumbs_<theme>).
            # This used to be a hardcoded ~/.cache/wallpaper_picker/thumbs,
            # which stopped existing when thumbnails became per-theme --
            # the glob below then matched nothing, so not one _HEX_ marker
            # was ever written, colorMap stayed empty, and every color
            # chip fell through to "no hex -> Monochrome": the color
            # filters looked broken because they had no data at all.
            # Markers are keyed by thumbnail basename, which is exactly
            # what the grid's model reports, so they line up 1:1.
            THUMBS='${settings.thumbDir}'
            CSV="$HOME/.cache/wallpaper_picker/colors.csv"
            
            mkdir -p "$COLOR_DIR"
            
            if [ -f "$CSV" ]; then
                while IFS=, read -r fname hexcode; do
                    cleanhex=$(echo "$hexcode" | tr -d '\r#' | cut -c 1-6)
                    if [ -n "$cleanhex" ] && [ -n "$fname" ]; then
                        touch "$COLOR_DIR/$fname""_HEX_$cleanhex" 2>/dev/null
                    fi
                done < "$CSV"
                mv "$CSV" "$CSV.bak" 2>/dev/null
            fi
            
            if command -v magick &> /dev/null; then CMD="magick"; else CMD="convert"; fi
            
            for file in "$THUMBS"/*; do
                if [ -f "$file" ]; then
                    filename=$(basename "$file")
                    found=0
                    for marker in "$COLOR_DIR/$filename"_HEX_*; do
                        if [ -e "$marker" ]; then found=1; break; fi
                    done
                    
                    if [ $found -eq 0 ]; then
                        hex=$($CMD "$file" -modulate 100,200 -resize "1x1^" -gravity center -extent 1x1 -depth 8 -format "%[hex:p{0,0}]" info:- 2>/dev/null | grep -oE '[0-9A-Fa-f]{6}' | head -n 1)
                        if [ -n "$hex" ]; then
                            touch "$COLOR_DIR/$filename""_HEX_$hex"
                        fi
                    fi
                fi
            done
        `;
        Quickshell.execDetached(["bash", "-c", extractScript]);
    }

    function stepToNextValidIndex(direction) {
        let targetModel = window.getModelForFilter(window.currentFilter);
        if (!targetModel || targetModel.count === 0) return;
        
        let start = view.currentIndex;
        let found = -1;

        if (direction === 1) {
            for (let i = start + 1; i < targetModel.count; i++) {
                let fname = targetModel.get(i).fileName || "";
                let isVid = window.checkIfVideo(fname);
                if (checkItemMatchesFilter(fname, isVid, window.cacheVersion, window.currentFilter)) {
                    found = i; break;
                }
            }
        } else {
            for (let i = start - 1; i >= 0; i--) {
                let fname = targetModel.get(i).fileName || "";
                let isVid = window.checkIfVideo(fname);
                if (checkItemMatchesFilter(fname, isVid, window.cacheVersion, window.currentFilter)) {
                    found = i; break;
                }
            }
        }

        if (found !== -1) {
            view.currentIndex = found;
            return;
        }

        let filterOrder = settings.enableColorFiltering
            ? ["All", "Video", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Monochrome"]
            : ["All", "Video"];
        let currentFilterIdx = filterOrder.indexOf(window.currentFilter);

        if (currentFilterIdx === -1) {
            let current = start;
            for (let i = 0; i < targetModel.count; i++) {
                current = (current + direction + targetModel.count) % targetModel.count;
                let fname = targetModel.get(current).fileName || "";
                let isVid = window.checkIfVideo(fname);
                
                if (checkItemMatchesFilter(fname, isVid, window.cacheVersion, window.currentFilter)) {
                    view.currentIndex = current;
                    return;
                }
            }
            return;
        }

        let nextFilterIdx = currentFilterIdx + direction;

        if (nextFilterIdx >= 0 && nextFilterIdx < filterOrder.length) {
            window.jumpToLastOnFilterChange = (direction === -1);
            window.currentFilter = filterOrder[nextFilterIdx];
        }
    }

    function cycleFilter(direction) {
        let activeFilters = settings.enableColorFiltering
            ? ["All", "Video", "Red", "Orange", "Yellow", "Green", "Blue", "Purple", "Pink", "Monochrome"]
            : ["All", "Video"];
        let currentIdx = activeFilters.indexOf(window.currentFilter);
        
        if (currentIdx !== -1) {
            let nextIdx = (currentIdx + direction + activeFilters.length) % activeFilters.length;
            window.currentFilter = activeFilters[nextIdx];
        } else {
            window.currentFilter = "All";
        }
    }

    function applyFilters(forceSnap) {
        let targetModel = window.getModelForFilter(window.currentFilter);
        
        if (!targetModel || targetModel.count === 0) {
            window.updateVisibleCount();
            return;
        }

        if (window.currentFilter === "Search") {
            window.updateVisibleCount();
            return; 
        }

        let firstValidIndex = -1;
        let lastValidIndex = -1;
        let cleanTarget = window.getCleanName(window.targetWallName);
        let targetIndex = -1;

        for (let i = 0; i < targetModel.count; i++) {
            let fname = targetModel.get(i).fileName || "";
            let isVid = window.checkIfVideo(fname);
            
            if (checkItemMatchesFilter(fname, isVid, window.cacheVersion, window.currentFilter)) {
                if (firstValidIndex === -1) {
                    firstValidIndex = i;
                }
                lastValidIndex = i;
                
                if (cleanTarget !== "" && window.getCleanName(fname) === cleanTarget) {
                    targetIndex = i;
                }
            }
        }

        let indexToFocus = -1;

        if (targetIndex !== -1) {
             indexToFocus = targetIndex;
        } else if (window.jumpToLastOnFilterChange && lastValidIndex !== -1) {
            indexToFocus = lastValidIndex;
        } else if (firstValidIndex !== -1) {
            indexToFocus = firstValidIndex;
        }

        window.jumpToLastOnFilterChange = false;
        
        if (indexToFocus !== -1) {
            window.executeFocusRestore(indexToFocus, false, forceSnap === true);
        }
        
        window.updateVisibleCount();
    }

    onCurrentFilterChanged: {
        window.isFilterAnimating = true;
        filterAnimationTimer.restart();
        window.isModelChanging = true; 
        let returningFromSearch = (window._lastFilter === "Search" && window.currentFilter !== "Search");
        window._lastFilter = window.currentFilter;
        
        if (returningFromSearch) {
             window.searchIndexRestored = false;
        }
        
        Qt.callLater(() => {
            view.forceActiveFocus();

            if (window.currentFilter === "Search") {
                if (window.hasSearched) {
                    window.searchIndexRestored = false; 
                    window.trySearchFocus();
                }
            } else {
                window.applyFilters(returningFromSearch);
            }
            window.isModelChanging = false;
        });
    }

    // -------------------------------------------------------------------------
    // SHORTCUTS
    // -------------------------------------------------------------------------
    // window.isReady gates all three of these -- until the folder scan
    // finishes, tryFocus() hasn't run yet and view.currentIndex isn't
    // settled. Without this, navigating during that window would move
    // currentIndex only for tryFocus() to unconditionally overwrite it
    // back once the scan completes, which is what made fast input right
    // after opening look like it "did nothing": your navigation was
    // silently stomped a second or two later. Escape is deliberately NOT
    // gated on this -- closing the picker should always work immediately,
    // loaded or not.
    Shortcut {
        sequence: "Left";
        enabled: window.isReady && !window.isScrollingBlocked && !window.isApplying
        onActivated: window.stepToNextValidIndex(-1)
    }
    Shortcut {
        sequence: "Right";
        enabled: window.isReady && !window.isScrollingBlocked && !window.isApplying
        onActivated: window.stepToNextValidIndex(1)
    }

    Shortcut {
        sequence: "Return"
        // Bind the lock firmly to the shortcut to stop multiple keyboard fires
        enabled: window.isReady && !searchInput.activeFocus && !window.isScrollingBlocked && !window.isApplying
        onActivated: { 
            let targetModel = window.getModelForFilter(window.currentFilter);
            if (view.currentIndex >= 0 && view.currentIndex < targetModel.count) {
                let fname = targetModel.get(view.currentIndex).fileName;
                if (fname) {
                    let isVid = window.checkIfVideo(fname);
                    window.applyWallpaper(String(fname), isVid);
                }
            }
        } 
    }
    
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: !window.isApplying
        onActivated: {
            if (window.currentFilter === "Search") {
                window.currentFilter = "All";
            } else {
                GlobalState.wallpaperPickerOpen = false;
            }
        }
    }
    Shortcut { sequence: "Tab"; enabled: !window.isApplying; onActivated: window.cycleFilter(1) }
    Shortcut { sequence: "Backtab"; enabled: !window.isApplying; onActivated: window.cycleFilter(-1) }

    // -------------------------------------------------------------------------
    // CONTENT & DUAL MODELS
    // -------------------------------------------------------------------------
    ListModel { id: localProxyModel }
    
    readonly property var activeModel: localProxyModel

    FolderListModel {
        id: localFolderModel
        folder: window.thumbDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.mp4", "*.mkv", "*.mov", "*.webm"]
        showDirs: false
        sortField: FolderListModel.Name 
        
        onCountChanged: window.syncLocalModel()
        onStatusChanged: { if (status === FolderListModel.Ready) window.syncLocalModel() }
    }

    property string _lastSyncedFolder: ""

    function syncLocalModel() {
        // "count shrank" used to be the only signal for "folder changed,
        // full rebuild needed" -- that was enough when the picker was a
        // fresh process per open (folder was fixed for its whole
        // lifetime, so this only ever had to handle a single scan's
        // count growing incrementally as FolderListModel discovered
        // files). Now that it's permanent and settings.thumbDir tracks
        // the live theme, the folder itself can change under it (switch
        // themes while the picker is closed, then reopen) -- if the new
        // theme happens to have as many or more wallpapers than the old
        // one had loaded, "shrank" never fires, so old entries never
        // get cleared and new ones get appended from the wrong offset:
        // the old theme's wallpapers stay mixed in, and some of the new
        // theme's get skipped entirely. Tracking the folder itself is
        // the actual signal, not a count heuristic that only sometimes
        // implies it.
        if (window._lastSyncedFolder !== localFolderModel.folder) {
            window._lastSyncedFolder = localFolderModel.folder;
            window.isModelChanging = true;
            localProxyModel.clear();
            window.isModelChanging = false;

            // Clearing the model orphans view.currentIndex -- nothing
            // matches ListView.isCurrentItem anymore, so the coverflow
            // delegate's isVisuallyEnlarged (the whole reason one item
            // renders at 1.5x while the rest sit at 0.5x) is false for
            // EVERY item, and the grid reads as uniformly tiny. initialFocusSet
            // being permanently true (set the first time this component
            // ever focused something, long before this folder change)
            // is exactly what stops tryFocus() from ever running again
            // to pick a new current item for the new folder's content.
            window.initialFocusSet = false;
            window.searchIndexRestored = false;
        }

        let startIdx = localProxyModel.count;
        let endIdx = localFolderModel.count;

        for (let i = startIdx; i < endIdx; i++) {
            let fn = localFolderModel.get(i, "fileName");
            let fu = localFolderModel.get(i, "fileUrl");
            if (fn !== undefined) {
                localProxyModel.append({ "fileName": fn, "fileUrl": String(fu) });
            }
        }

        // updateVisibleCount() rescans the WHOLE model every time it runs.
        // FolderListModel fires countChanged incrementally as each file is
        // discovered, so calling this unconditionally here turns the
        // initial folder scan into O(n^2) (a full rescan after every
        // single new file). None of that intermediate count is ever
        // actually shown -- showNotification is already suppressed while
        // isStartup (status === Loading) -- so it's safe to skip until the
        // scan is done; onStatusChanged re-invokes syncLocalModel() once
        // more right when status flips to Ready, which is when this
        // finally needs to run (and does, with the complete model).
        if (window.currentFilter !== "Search" && localFolderModel.status === FolderListModel.Ready) {
            window.updateVisibleCount();
        }

        // tryFocus() itself waits for the folder scan to actually finish
        // before doing anything (see its own comment) -- safe to call
        // eagerly on every partial batch here.
        if (!window.initialFocusSet && window.currentFilter !== "Search" && localProxyModel.count > 0) {
            window.tryFocus();
        }
    }

    ListView {
        id: view
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: window.itemHeight + window.s(60)
        
        opacity: window.isReady ? 1.0 : 0.0
        anchors.leftMargin: window.isReady ? 0 : window.s(40)
        anchors.rightMargin: window.isReady ? 0 : window.s(40)
        
        Behavior on opacity { NumberAnimation { duration: window.anim(600); easing.type: Easing.OutQuart } }
        Behavior on anchors.leftMargin { NumberAnimation { duration: window.anim(700); easing.type: Easing.OutExpo } }
        Behavior on anchors.rightMargin { NumberAnimation { duration: window.anim(700); easing.type: Easing.OutExpo } }

        spacing: 0
        orientation: ListView.Horizontal
        clip: false 

        interactive: !window.isScrollingBlocked && !window.isApplying
        cacheBuffer: 2000

        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: (width / 2) - ((window.itemWidth * 1.5 + window.spacing) / 2)
        preferredHighlightEnd: (width / 2) + ((window.itemWidth * 1.5 + window.spacing) / 2)
        
        highlightMoveDuration: window.initialFocusSet ? window.anim(500) : 0
        focus: true
        
        onCurrentIndexChanged: {
            window.isItemAnimating = true;
            itemAnimationTimer.restart();

            if (window.currentFilter !== "Search") return;
            
            if (!window.isModelChanging && window.hasSearched && window.searchIndexRestored) {
                if (currentIndex >= 0 && currentIndex < localProxyModel.count) {
                    let fname = localProxyModel.get(currentIndex).fileName;
                    if (fname !== undefined && fname !== "") {
                        window.lastSearchName = String(fname);
                        searchState.lastName = String(fname);
                    }
                }
            }
        }
        
        add: Transition {
            enabled: window.initialFocusSet
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: window.anim(400); easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.5; to: 1; duration: window.anim(400); easing.type: Easing.OutBack }
            }
        }
        addDisplaced: Transition {
            enabled: window.initialFocusSet
            NumberAnimation { property: "x"; duration: window.anim(400); easing.type: Easing.OutCubic }
        }

        header: Item { width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.5) / 2)) }
        footer: Item { width: Math.max(0, (view.width / 2) - ((window.itemWidth * 1.5) / 2)) }

        model: window.activeModel

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton 

            onWheel: (wheel) => {
                // Same isReady gate as the Left/Right shortcuts -- see the
                // comment above them for why.
                if (!window.isReady || window.isScrollingBlocked || window.isApplying) {
                    wheel.accepted = true;
                    return;
                }

                if (scrollThrottle.running) {
                   wheel.accepted = true
                   return
                }

                let dx = wheel.angleDelta.x
                let dy = wheel.angleDelta.y
                let delta = Math.abs(dx) > Math.abs(dy) ? dx : dy

                scrollAccum += delta

                if (Math.abs(scrollAccum) >= scrollThreshold) {
                    window.stepToNextValidIndex(scrollAccum > 0 ? -1 : 1)
                    scrollAccum = 0
                    scrollThrottle.start()
                }

                wheel.accepted = true
            }        
        }

        delegate: Item {
            id: delegateRoot
            
            readonly property string safeFileName: fileName !== undefined ? String(fileName) : ""
            
            readonly property bool isCurrent: ListView.isCurrentItem && !window.isScrollingBlocked
            readonly property bool isFakeSelected: window.isScrollingBlocked && index === 0
            readonly property bool isVisuallyEnlarged: isCurrent || isFakeSelected
            
            readonly property bool isVideo: window.checkIfVideo(safeFileName)
            readonly property bool matchesFilter: window.checkItemMatchesFilter(safeFileName, isVideo, window.cacheVersion, window.currentFilter)
            
            readonly property real targetWidth: isVisuallyEnlarged ? (window.itemWidth * 1.5) : (window.itemWidth * 0.5)
            readonly property real targetHeight: isVisuallyEnlarged ? (window.itemHeight + window.s(30)) : window.itemHeight 
            
            property bool isPlayingVideo: false

            Timer {
                id: videoPlayTimer
                interval: 250
                running: delegateRoot.isVisuallyEnlarged && delegateRoot.isVideo && !window.isScrollingBlocked && !window.isFilterAnimating && !window.isItemAnimating
                onTriggered: {
                    if (delegateRoot.isVisuallyEnlarged && delegateRoot.isVideo) {
                        delegateRoot.isPlayingVideo = true;
                    }
                }
            }

            onIsVisuallyEnlargedChanged: {
                if (!isVisuallyEnlarged) {
                    isPlayingVideo = false;
                    videoPlayTimer.stop();
                }
            }
            
            width: matchesFilter ? (targetWidth + window.spacing) : 0
            visible: width > 0.1 || opacity > 0.01
            opacity: matchesFilter ? (isVisuallyEnlarged ? 1.0 : 0.6) : 0.0
            
            scale: matchesFilter ? 1.0 : 0.5

            height: matchesFilter ? targetHeight : 0
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            anchors.verticalCenterOffset: parent ? window.s(0) : 0 

            z: isVisuallyEnlarged ? 10 : 1
            
            Behavior on scale { enabled: window.initialFocusSet; NumberAnimation { duration: window.anim(500); easing.type: Easing.InOutQuad } }
            Behavior on width { enabled: window.initialFocusSet; NumberAnimation { duration: window.anim(500); easing.type: Easing.InOutQuad } }
            Behavior on height { enabled: window.initialFocusSet; NumberAnimation { duration: window.anim(500); easing.type: Easing.InOutQuad } } 
            Behavior on opacity { enabled: window.initialFocusSet; NumberAnimation { duration: window.anim(500); easing.type: Easing.InOutQuad } }

            Item {
                anchors.centerIn: parent
                anchors.horizontalCenterOffset: ((window.itemHeight - height) / 2) * window.skewFactor
                
                width: parent.width > 0 ? parent.width * (targetWidth / (targetWidth + window.spacing)) : 0
                height: parent.height

                transform: Matrix4x4 {
                    property real s: window.skewFactor
                    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                }
                
                MouseArea {
                    anchors.fill: parent
                    // Lock inputs completely on the delegate as well
                    enabled: delegateRoot.matchesFilter && !window.isScrollingBlocked && !window.isApplying
                    onClicked: {
                        view.currentIndex = index
                        window.applyWallpaper(delegateRoot.safeFileName, delegateRoot.isVideo)
                    }
                }

                Image {
                    anchors.fill: parent
                    source: fileUrl !== undefined ? fileUrl : ""
                    sourceSize: Qt.size(1, 1)
                    fillMode: Image.Stretch
                    visible: true 
                    asynchronous: true
                }

                Item {
                    anchors.fill: parent
                    anchors.margins: window.borderWidth 
                    Rectangle { anchors.fill: parent; color: "black" }
                    clip: true

                    Image {
                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: window.s(-50) 
                        width: (window.itemWidth * 1.5) + ((window.itemHeight + window.s(30)) * Math.abs(window.skewFactor)) + window.s(50)
                        height: window.itemHeight + window.s(30)
                        fillMode: Image.PreserveAspectCrop
                        source: fileUrl !== undefined ? fileUrl : ""
                        asynchronous: true

                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                    }
                    
                    Loader {
                        id: videoLoader
                        active: delegateRoot.isPlayingVideo
                        anchors.fill: parent

                        sourceComponent: Item {
                            anchors.fill: parent

                            MediaPlayer {
                                id: previewPlayer
                                source: "file://" + window.srcDir + "/" + window.getCleanName(delegateRoot.safeFileName)
                                audioOutput: AudioOutput { muted: true }
                                videoOutput: previewOutput
                                loops: MediaPlayer.Infinite
                                Component.onCompleted: previewPlayer.play()
                            }

                            VideoOutput {
                                id: previewOutput
                                anchors.centerIn: parent
                                anchors.horizontalCenterOffset: window.s(-50) 
                                width: (window.itemWidth * 1.5) + ((window.itemHeight + window.s(30)) * Math.abs(window.skewFactor)) + window.s(50)
                                height: window.itemHeight + window.s(30)
                                fillMode: VideoOutput.PreserveAspectCrop

                                transform: Matrix4x4 {
                                    property real s: -window.skewFactor
                                    matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                }
                            }

                            property int playbackState: previewPlayer.playbackState
                        }
                    }
                    
                    Rectangle {
                        visible: delegateRoot.isVideo && (!delegateRoot.isPlayingVideo || (videoLoader.item && videoLoader.item.playbackState !== MediaPlayer.PlayingState))
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.margins: window.s(10)
                        width: window.s(32)
                        height: window.s(32)
                        radius: window.s(6)
                        color: "#60000000" 
                        transform: Matrix4x4 {
                            property real s: -window.skewFactor
                            matrix: Qt.matrix4x4(1, s, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        }
                        
                        Canvas {
                            anchors.fill: parent
                            anchors.margins: window.s(8)
                            property real scaleTrigger: window.s(1)
                            onScaleTriggerChanged: requestPaint()
                            onPaint: {
                                var ctx = getContext("2d");
                                var s = window.s;
                                ctx.reset();
                                ctx.fillStyle = "#EEFFFFFF"; 
                                ctx.beginPath();
                                ctx.moveTo(s(4), 0);
                                ctx.lineTo(s(14), s(8));
                                ctx.lineTo(s(4), s(16));
                                ctx.closePath();
                                ctx.fill();
                            }
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // FLOATING FILTER BAR & INLINE NOTIFICATION DRAWER
    // -------------------------------------------------------------------------
    Rectangle {
        id: filterBarBackground
        anchors.bottom: parent.bottom
        
        anchors.bottomMargin: window.isReady ? window.s(6) : window.s(-100) 
        opacity: window.isReady ? 1.0 : 0.0
        Behavior on anchors.bottomMargin { NumberAnimation { duration: window.anim(600); easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: window.anim(500); easing.type: Easing.OutCubic } }

        anchors.horizontalCenter: parent.horizontalCenter
        z: 20
        height: window.s(56)
        width: filterRow.width + window.s(24)
        radius: window.s(14) 
        
        color: Qt.rgba(_theme.mantle.r, _theme.mantle.g, _theme.mantle.b, 0.90)
        border.color: Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.8)
        border.width: 1

        Row {
            id: filterRow
            anchors.centerIn: parent
            spacing: window.s(12)

            Rectangle {
                id: notifDrawer
                height: window.s(44)
                property real paddingLeft: window.showSpinner ? window.s(40) : window.s(16)
                property real targetWidth: window.showNotification ? Math.min(notifTextDrawer.implicitWidth + paddingLeft + window.s(20), window.s(300)) : 0
                width: targetWidth
                visible: width > 0.1 
                radius: window.s(10) 
                clip: true
                
                color: window.showNotification ? Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.5) : "transparent"
                border.color: window.showNotification ? Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.8) : "transparent"
                border.width: 1

                Behavior on width { 
                    NumberAnimation { duration: window.anim(600); easing.type: Easing.OutBack; easing.overshoot: 0.5 } 
                }
                Behavior on color { ColorAnimation { duration: window.anim(400) } }
                Behavior on border.color { ColorAnimation { duration: window.anim(400) } }

                Item {
                    visible: window.showSpinner
                    width: window.s(44)
                    height: window.s(44)
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        id: notifSpinner
                        width: window.s(14)
                        height: window.s(14)
                        anchors.centerIn: parent
                        property real scaleTrigger: window.s(1)
                        onScaleTriggerChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            var s = window.s;
                            ctx.reset();
                            ctx.lineWidth = s(2);
                            ctx.strokeStyle = Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.3);
                            ctx.beginPath();
                            ctx.arc(s(7), s(7), s(5), 0, Math.PI * 2);
                            ctx.stroke();
                            
                            ctx.strokeStyle = Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.9);
                            ctx.beginPath();
                            ctx.arc(s(7), s(7), s(5), 0, Math.PI * 0.5);
                            ctx.stroke();
                        }
                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0; to: 360
                            duration: window.anim(800)
                            running: window.showSpinner && window.showNotification
                        }
                    }
                }

                Text {
                    id: notifTextDrawer
                    anchors.left: parent.left
                    anchors.leftMargin: window.showSpinner ? window.s(40) : window.s(16)
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, window.s(300) - anchors.leftMargin - window.s(16))
                    text: window.currentNotification
                    
                    color: _theme.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(14)
                    font.bold: true
                    elide: Text.ElideRight

                    opacity: window.showNotification ? 0.9 : 0.0
                    Behavior on opacity { NumberAnimation { duration: window.anim(400); easing.type: Easing.OutQuad } }
                    Behavior on anchors.leftMargin { 
                        NumberAnimation { duration: window.anim(600); easing.type: Easing.OutBack; easing.overshoot: 0.5 } 
                    }
                }
            }

            Repeater {
                model: window.filterData

                delegate: Item {
                    visible: modelData.name !== "Search" && (settings.enableColorFiltering || modelData.hex === "")
                    width: !visible ? 0 : ((modelData.name === "Video" || modelData.name === "All") ? window.s(44) : (modelData.hex === "" ? filterText.contentWidth + window.s(24) : window.s(36)))
                    height: !visible ? 0 : window.s(36)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    Rectangle {
                        anchors.fill: parent
                        radius: window.s(10) 
                        color: modelData.hex === "" 
                                ? (window.currentFilter === modelData.name ? _theme.surface2 : "transparent") 
                                : modelData.hex
                        
                        border.color: window.currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.6)
                        border.width: window.currentFilter === modelData.name ? window.s(2) : 1
                        scale: window.currentFilter === modelData.name ? 1.15 : (filterMouse.containsMouse ? 1.08 : 1.0)
                        
                        Behavior on scale { NumberAnimation { duration: window.anim(400); easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                        Behavior on border.color { ColorAnimation { duration: 300 } }

                        Text {
                            id: filterText
                            visible: modelData.hex === "" && modelData.name !== "Video" && modelData.name !== "All"
                            text: modelData.label
                            anchors.centerIn: parent
                            color: window.currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                            font.family: "JetBrains Mono"
                            font.pixelSize: window.s(14)
                            font.bold: window.currentFilter === modelData.name
                            Behavior on color { ColorAnimation { duration: window.anim(400); easing.type: Easing.OutQuart } }
                        }

                        Canvas {
                            visible: modelData.name === "Video"
                            width: window.s(14); height: window.s(16)
                            anchors.centerIn: parent
                            anchors.horizontalCenterOffset: window.s(2) 
                            property string activeColor: window.currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                            onActiveColorChanged: requestPaint()
                            property real scaleTrigger: window.s(1)
                            onScaleTriggerChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                var s = window.s;
                                ctx.reset();
                                ctx.fillStyle = activeColor; 
                                ctx.beginPath();
                                ctx.moveTo(0, 0);
                                ctx.lineTo(s(14), s(8));
                                ctx.lineTo(0, s(16));
                                ctx.closePath();
                                ctx.fill();
                            }
                        }

                        Canvas {
                            visible: modelData.name === "All"
                            width: window.s(14); height: window.s(14)
                            anchors.centerIn: parent
                            property string activeColor: window.currentFilter === modelData.name ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7)
                            onActiveColorChanged: requestPaint()
                            property real scaleTrigger: window.s(1)
                            onScaleTriggerChanged: requestPaint()

                            onPaint: {
                                var ctx = getContext("2d");
                                var s = window.s;
                                ctx.reset();
                                ctx.fillStyle = activeColor;
                                ctx.fillRect(0, 0, s(6), s(6));
                                ctx.fillRect(s(8), 0, s(6), s(6));
                                ctx.fillRect(0, s(8), s(6), s(6));
                                ctx.fillRect(s(8), s(8), s(6), s(6));
                            }
                        }
                    }

                    MouseArea {
                        id: filterMouse
                        anchors.fill: parent
                        hoverEnabled: true 
                        enabled: !window.isApplying // Lock UI interaction
                        onClicked: window.currentFilter = modelData.name
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }


            Rectangle {
                id: searchBox
                // Only show search when color filtering is enabled (matugen mode);
                // custom themes have few wallpapers and don't need it.
                visible: settings.enableColorFiltering
                height: window.s(44)
                width: window.currentFilter === "Search" ? window.s(360) : window.s(44)
                radius: window.s(10)
                clip: true
                
                color: window.currentFilter === "Search" ? Qt.rgba(_theme.surface2.r, _theme.surface2.g, _theme.surface2.b, 0.8) : "transparent"
                border.color: window.currentFilter === "Search" ? Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.5) : Qt.rgba(_theme.surface1.r, _theme.surface1.g, _theme.surface1.b, 0.6)
                border.width: window.currentFilter === "Search" ? window.s(2) : 1
                
                Behavior on width { NumberAnimation { duration: window.anim(600); easing.type: Easing.OutBack; easing.overshoot: 0.5 } }
                Behavior on color { ColorAnimation { duration: window.anim(400); easing.type: Easing.OutQuart } }
                Behavior on border.color { ColorAnimation { duration: window.anim(400) } }

                MouseArea {
                    id: searchMouseArea
                    anchors.fill: parent
                    hoverEnabled: true 
                    enabled: !window.isApplying // Lock UI interaction
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (window.currentFilter !== "Search") {
                            window.currentFilter = "Search"
                        } else {
                            window.currentFilter = "All" 
                        }
                    }
                }

                Canvas {
                    id: searchIcon
                    width: window.s(44)
                    height: window.s(44)
                    anchors.left: parent.left
                    anchors.leftMargin: window.currentFilter === "Search" ? window.s(5) : 0 
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on anchors.leftMargin { NumberAnimation { duration: window.anim(500); easing.type: Easing.OutExpo } }
                    property string activeColor: window.currentFilter === "Search" ? _theme.text : (searchMouseArea.containsMouse ? _theme.text : Qt.rgba(_theme.text.r, _theme.text.g, _theme.text.b, 0.7))
                    onActiveColorChanged: requestPaint()
                    property real scaleTrigger: window.s(1)
                    onScaleTriggerChanged: requestPaint()

                    onPaint: {
                        var ctx = getContext("2d");
                        var s = window.s;
                        ctx.reset();
                        ctx.lineWidth = s(3); 
                        ctx.strokeStyle = activeColor;
                        ctx.beginPath();
                        ctx.arc(s(18), s(18), s(7), 0, Math.PI * 2);
                        ctx.stroke();
                        ctx.beginPath();
                        ctx.moveTo(s(23), s(23));
                        ctx.lineTo(s(31), s(31));
                        ctx.stroke();
                    }
                }

                TextInput {
                    id: searchInput
                    anchors.left: searchIcon.right
                   anchors.right: parent.right
                   anchors.rightMargin: window.s(12)
                    anchors.verticalCenter: parent.verticalCenter
                    
                    opacity: window.currentFilter === "Search" ? 1.0 : 0.0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: window.anim(400); easing.type: Easing.OutQuad } }
                    
                    color: _theme.text
                    font.family: "JetBrains Mono"
                    font.pixelSize: window.s(16) 
                    clip: true
                    
                    onTextEdited: {
                        window.searchQuery = text.trim().toLowerCase()

                        window.currentFilter = "Search"
                        window.hasSearched = true
                        window.isOnlineSearch = false
                        window.isSearchPaused = true

                        searchState.searched = true
                        searchState.query = window.searchQuery

                        view.currentIndex = 0
                        window.updateVisibleCount()
                        window.applyFilters(true)
                    }
                    
                    onAccepted: {
                        window.triggerLocalSearch();
                        searchInput.focus = false; 
                        view.forceActiveFocus();
                    }
                }

            }
        }
    }

    // One-time setup -- anything that needs to happen on every open lives
    // in onPickerOpened() instead, fired from onVisibleChanged above.
    //
    // This component is no longer constructed at island startup: shell.qml
    // wraps it in a Loader that only builds it the first time the picker
    // is actually opened (it's a heavy tree to pay for on every boot for a
    // window behind SUPER+SHIFT+W). It's still permanent from then on, so
    // the split between this and onPickerOpened() still matters -- but on
    // that FIRST open `visible` is already true at construction, so
    // onVisibleChanged never fires and onPickerOpened() has to be kicked
    // off from here as well. callLater so it runs after the search-state
    // restore just below, which it reads.
    Component.onCompleted: {
        Quickshell.execDetached(["bash", "-c", "mkdir -p '" + decodeURIComponent(window.searchDir.replace("file://", "")) + "'"]);

        if (searchState.searched) {
            searchInput.text = searchState.query;
            window.searchQuery = searchState.query;
            window.hasSearched = true;
            window.lastSearchName = searchState.lastName;
            window.isSearchPaused = true;
        }

        if (window.visible)
            Qt.callLater(window.onPickerOpened);
    }

    Component.onDestruction: {
        if (window.hasSearched) {
            searchState.query = searchInput.text;
            searchState.searched = window.hasSearched;
            searchState.lastName = window.lastSearchName;
        }
    }
}
