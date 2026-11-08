#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#include <dlfcn.h>
#include <string.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  GtkWindow* window;
  GtkStatusIcon* tray;
  // a statusnotifieritem through libayatana-appindicator, when the desktop
  // has a host for one (gnome's appindicator extension, kde, xfce)
  GObject* indicator;
  GtkWidget* tray_menu;
  FlMethodChannel* desktop_channel;
  guint quit_timer;
  // started with the computer (--hidden): no window until asked for
  gboolean start_hidden;
  guint hidden_timer;
  // said once, the first time closing the window hides kryfo to the tray
  gchar* tray_hint;
};

// how long a hidden start waits for its tray icon before the window shows
static const guint kHiddenWaitSeconds = 10;

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// the tray keeps the app running with the window closed, so messages keep
// arriving. a statusnotifieritem first (gnome on wayland shows only that,
// through its appindicator extension), else gtk's status icon for x11 trays;
// on a desktop without a tray, closing the window ends the app as before
G_GNUC_BEGIN_IGNORE_DEPRECATIONS

static void show_window(MyApplication* self) {
  if (self->hidden_timer != 0) {
    g_source_remove(self->hidden_timer);
    self->hidden_timer = 0;
  }
  if (self->window == nullptr) return;
  gtk_widget_show(GTK_WIDGET(self->window));
  gtk_window_present(self->window);
}

// libayatana-appindicator3 is opened at run time, so the app starts without
// it and falls back to gtk's status icon
typedef struct {
  GObject* (*new_with_path)(const gchar*, const gchar*, int, const gchar*);
  void (*set_status)(GObject*, int);
  void (*set_menu)(GObject*, GtkMenu*);
  void (*set_title)(GObject*, const gchar*);
  void (*set_secondary)(GObject*, GtkWidget*);
} Indicator;

static const int kIndicatorCommunications = 1;
static const int kIndicatorPassive = 0;
static const int kIndicatorActive = 1;

static const Indicator* indicator_lib() {
  static Indicator lib;
  static int state = 0;
  if (state != 0) return state > 0 ? &lib : nullptr;
  state = -1;
  const char* names[] = {"libayatana-appindicator3.so.1",
                         "libappindicator3.so.1"};
  for (const char* name : names) {
    void* h = dlopen(name, RTLD_NOW | RTLD_LOCAL);
    if (h == nullptr) continue;
    lib.new_with_path = reinterpret_cast<decltype(lib.new_with_path)>(
        dlsym(h, "app_indicator_new_with_path"));
    lib.set_status = reinterpret_cast<decltype(lib.set_status)>(
        dlsym(h, "app_indicator_set_status"));
    lib.set_menu = reinterpret_cast<decltype(lib.set_menu)>(
        dlsym(h, "app_indicator_set_menu"));
    lib.set_title = reinterpret_cast<decltype(lib.set_title)>(
        dlsym(h, "app_indicator_set_title"));
    lib.set_secondary = reinterpret_cast<decltype(lib.set_secondary)>(
        dlsym(h, "app_indicator_set_secondary_activate_target"));
    if (lib.new_with_path != nullptr && lib.set_status != nullptr &&
        lib.set_menu != nullptr) {
      state = 1;
      return &lib;
    }
    dlclose(h);
  }
  return nullptr;
}

// someone on the session bus shows statusnotifieritems
static gboolean sni_host() {
  g_autoptr(GDBusConnection) bus =
      g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, nullptr);
  if (bus == nullptr) return FALSE;
  g_autoptr(GVariant) r = g_dbus_connection_call_sync(
      bus, "org.freedesktop.DBus", "/org/freedesktop/DBus",
      "org.freedesktop.DBus", "NameHasOwner",
      g_variant_new("(s)", "org.kde.StatusNotifierWatcher"),
      G_VARIANT_TYPE("(b)"), G_DBUS_CALL_FLAGS_NONE, 1000, nullptr, nullptr);
  if (r == nullptr) return FALSE;
  gboolean owned = FALSE;
  g_variant_get(r, "(b)", &owned);
  return owned;
}

static gboolean tray_shown(MyApplication* self) {
  if (self->indicator != nullptr) return sni_host();
  return self->tray != nullptr && gtk_status_icon_is_embedded(self->tray);
}

// a hidden start on a desktop with no tray: the window after all
static gboolean hidden_timed_out(gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->hidden_timer = 0;
  if (!tray_shown(self)) show_window(self);
  return G_SOURCE_REMOVE;
}

static void tray_open_cb(GtkMenuItem*, gpointer user_data) {
  show_window(MY_APPLICATION(user_data));
}

static gboolean quit_timed_out(gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  self->quit_timer = 0;
  g_application_quit(G_APPLICATION(self));
  return G_SOURCE_REMOVE;
}

static void quit_answered_cb(GObject*, GAsyncResult*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->quit_timer == 0) return;
  g_source_remove(self->quit_timer);
  self->quit_timer = 0;
  g_application_quit(G_APPLICATION(self));
}

// dart keeps what it keeps and clears memory first; three seconds at most
static void tray_quit_cb(GtkMenuItem*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (self->desktop_channel == nullptr) {
    g_application_quit(G_APPLICATION(self));
    return;
  }
  if (self->quit_timer != 0) return;
  self->quit_timer = g_timeout_add_seconds(3, quit_timed_out, self);
  fl_method_channel_invoke_method(self->desktop_channel, "quit", nullptr,
                                  nullptr, quit_answered_cb, self);
}

static void tray_activate_cb(GtkStatusIcon*, gpointer user_data) {
  show_window(MY_APPLICATION(user_data));
}

static void tray_popup_cb(GtkStatusIcon* icon, guint button, guint time,
                          gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  gtk_menu_popup(GTK_MENU(self->tray_menu), nullptr, nullptr,
                 gtk_status_icon_position_menu, icon, button, time);
}

static gchar* data_dir() {
  g_autofree gchar* exe = g_file_read_link("/proc/self/exe", nullptr);
  if (exe == nullptr) return nullptr;
  g_autofree gchar* dir = g_path_get_dirname(exe);
  return g_build_filename(dir, "data", nullptr);
}

static gchar* icon_path() {
  g_autofree gchar* dir = data_dir();
  if (dir == nullptr) return nullptr;
  return g_build_filename(dir, "kryfo.png", nullptr);
}

// data/kryfo.png is the indicator's icon, found by name in data/
static gboolean make_indicator(MyApplication* self, GtkWidget* open_item) {
  const Indicator* lib = indicator_lib();
  if (lib == nullptr) return FALSE;
  if (self->indicator == nullptr) {
    if (!sni_host()) return FALSE;
    g_autofree gchar* dir = data_dir();
    self->indicator = lib->new_with_path(APPLICATION_ID, "kryfo",
                                         kIndicatorCommunications, dir);
    if (self->indicator == nullptr) return FALSE;
  }
  lib->set_menu(self->indicator, GTK_MENU(self->tray_menu));
  if (lib->set_title != nullptr) lib->set_title(self->indicator, "Kryfo");
  if (lib->set_secondary != nullptr) {
    lib->set_secondary(self->indicator, open_item);
  }
  lib->set_status(self->indicator, kIndicatorActive);
  return TRUE;
}

static void drop_indicator(MyApplication* self) {
  if (self->indicator == nullptr) return;
  const Indicator* lib = indicator_lib();
  if (lib != nullptr) lib->set_status(self->indicator, kIndicatorPassive);
  g_clear_object(&self->indicator);
}

// dart sends the menu's words in the app's language once it knows them
static void make_tray(MyApplication* self, const gchar* open,
                      const gchar* quit, const gchar* tip) {
  GtkWidget* old_menu = self->tray_menu;
  self->tray_menu = gtk_menu_new();
  GtkWidget* open_item = gtk_menu_item_new_with_label(open);
  GtkWidget* quit_item = gtk_menu_item_new_with_label(quit);
  g_signal_connect(open_item, "activate", G_CALLBACK(tray_open_cb), self);
  g_signal_connect(quit_item, "activate", G_CALLBACK(tray_quit_cb), self);
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), open_item);
  gtk_menu_shell_append(GTK_MENU_SHELL(self->tray_menu), quit_item);
  gtk_widget_show_all(self->tray_menu);
  // the indicator takes the new menu before the old one goes
  gboolean indicated = self->tray == nullptr && make_indicator(self, open_item);
  if (old_menu != nullptr) gtk_widget_destroy(old_menu);
  if (indicated) return;
  if (self->tray == nullptr) {
    g_autofree gchar* path = icon_path();
    self->tray = path != nullptr && g_file_test(path, G_FILE_TEST_EXISTS)
                     ? gtk_status_icon_new_from_file(path)
                     : gtk_status_icon_new_from_icon_name(APPLICATION_ID);
    g_signal_connect(self->tray, "activate", G_CALLBACK(tray_activate_cb),
                     self);
    g_signal_connect(self->tray, "popup-menu", G_CALLBACK(tray_popup_cb),
                     self);
  }
  gtk_status_icon_set_tooltip_text(self->tray, tip);
  gtk_status_icon_set_title(self->tray, "Kryfo");
}

G_GNUC_END_IGNORE_DEPRECATIONS

static const gchar* map_string(FlValue* args, const gchar* key) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP) {
    return "";
  }
  FlValue* v = fl_value_lookup_string(args, key);
  if (v == nullptr || fl_value_get_type(v) != FL_VALUE_TYPE_STRING) return "";
  return fl_value_get_string(v);
}

// the tray switch off: the icon goes, and closing the window quits
static void drop_tray(MyApplication* self) {
  drop_indicator(self);
  if (self->tray != nullptr) {
    G_GNUC_BEGIN_IGNORE_DEPRECATIONS
    gtk_status_icon_set_visible(self->tray, FALSE);
    G_GNUC_END_IGNORE_DEPRECATIONS
    g_clear_object(&self->tray);
  }
  if (self->tray_menu != nullptr) {
    gtk_widget_destroy(self->tray_menu);
    self->tray_menu = nullptr;
  }
}

// a flatpak starts with the computer through the background portal, which
// writes the host's autostart entry itself and may ask the user first
typedef struct {
  FlMethodCall* call;
  GDBusConnection* bus;
  guint signal_id;
  guint timer;
  gboolean on;
  gboolean done;
  // held by the dbus call and by the answer still owed
  int refs;
} PortalAsk;

static void portal_unref(PortalAsk* ask) {
  if (--ask->refs > 0) return;
  g_object_unref(ask->call);
  g_object_unref(ask->bus);
  g_free(ask);
}

static void portal_finish(PortalAsk* ask, FlValue* result) {
  g_autoptr(FlValue) owned = result;
  if (ask->done) return;
  ask->done = TRUE;
  if (ask->signal_id != 0) {
    g_dbus_connection_signal_unsubscribe(ask->bus, ask->signal_id);
    ask->signal_id = 0;
  }
  if (ask->timer != 0) g_source_remove(ask->timer);
  ask->timer = 0;
  fl_method_call_respond_success(ask->call, result, nullptr);
  portal_unref(ask);
}

static void portal_response_cb(GDBusConnection*, const gchar*, const gchar*,
                               const gchar*, const gchar*,
                               GVariant* parameters, gpointer user_data) {
  PortalAsk* ask = static_cast<PortalAsk*>(user_data);
  guint32 response = 2;
  g_autoptr(GVariant) results = nullptr;
  g_variant_get(parameters, "(u@a{sv})", &response, &results);
  gboolean autostart = FALSE;
  if (response == 0 && results != nullptr) {
    g_variant_lookup(results, "autostart", "b", &autostart);
  }
  // granted only when the portal now has it as asked
  portal_finish(ask, fl_value_new_bool(response == 0 && autostart == ask->on));
}

static guint portal_subscribe(PortalAsk* ask, const gchar* path) {
  return g_dbus_connection_signal_subscribe(
      ask->bus, "org.freedesktop.portal.Desktop",
      "org.freedesktop.portal.Request", "Response", path, nullptr,
      G_DBUS_SIGNAL_FLAGS_NO_MATCH_RULE, portal_response_cb, ask, nullptr);
}

static void portal_called_cb(GObject* source, GAsyncResult* res,
                             gpointer user_data) {
  PortalAsk* ask = static_cast<PortalAsk*>(user_data);
  g_autoptr(GError) error = nullptr;
  g_autoptr(GVariant) reply =
      g_dbus_connection_call_finish(G_DBUS_CONNECTION(source), res, &error);
  if (reply == nullptr) {
    portal_finish(ask, fl_value_new_null());
  } else if (!ask->done) {
    // an older portal answers on a path of its own
    const gchar* handle = nullptr;
    g_variant_get(reply, "(&o)", &handle);
    g_dbus_connection_signal_unsubscribe(ask->bus, ask->signal_id);
    ask->signal_id = portal_subscribe(ask, handle);
  }
  portal_unref(ask);
}

static gboolean portal_timed_out(gpointer user_data) {
  PortalAsk* ask = static_cast<PortalAsk*>(user_data);
  ask->timer = 0;
  portal_finish(ask, fl_value_new_null());
  return G_SOURCE_REMOVE;
}

static void ask_portal(FlMethodCall* call, gboolean on, const gchar* reason) {
  g_autoptr(GError) error = nullptr;
  GDBusConnection* bus = g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (bus == nullptr) {
    g_autoptr(FlValue) none = fl_value_new_null();
    fl_method_call_respond_success(call, none, nullptr);
    return;
  }
  PortalAsk* ask = g_new0(PortalAsk, 1);
  ask->call = FL_METHOD_CALL(g_object_ref(call));
  ask->bus = bus;
  ask->on = on;
  ask->refs = 2;
  g_autofree gchar* token = g_strdup_printf("kryfo%u", g_random_int());
  g_autofree gchar* sender =
      g_strdup(g_dbus_connection_get_unique_name(bus) + 1);
  g_strdelimit(sender, ".", '_');
  g_autofree gchar* path = g_strdup_printf(
      "/org/freedesktop/portal/desktop/request/%s/%s", sender, token);
  // subscribed before the call, so a quick answer is not missed
  ask->signal_id = portal_subscribe(ask, path);
  // the user may be asked: a minute and a half to answer
  ask->timer = g_timeout_add_seconds(90, portal_timed_out, ask);
  // the start with the computer comes up in the tray
  const gchar* command[] = {"kryfo", "--hidden", nullptr};
  GVariantBuilder options;
  g_variant_builder_init(&options, G_VARIANT_TYPE_VARDICT);
  g_variant_builder_add(&options, "{sv}", "handle_token",
                        g_variant_new_string(token));
  g_variant_builder_add(&options, "{sv}", "reason",
                        g_variant_new_string(reason));
  g_variant_builder_add(&options, "{sv}", "autostart",
                        g_variant_new_boolean(on));
  g_variant_builder_add(&options, "{sv}", "commandline",
                        g_variant_new_strv(command, -1));
  g_variant_builder_add(&options, "{sv}", "dbus-activatable",
                        g_variant_new_boolean(FALSE));
  g_dbus_connection_call(
      bus, "org.freedesktop.portal.Desktop", "/org/freedesktop/portal/desktop",
      "org.freedesktop.portal.Background", "RequestBackground",
      g_variant_new("(sa{sv})", "", &options), G_VARIANT_TYPE("(o)"),
      G_DBUS_CALL_FLAGS_NONE, -1, nullptr, portal_called_cb, ask);
}

// ctrl and v in a composer or on the tools tab, as windows' runner answers
// it: the files a file manager copied as paths, a copied picture as png
// bytes. the clipboard is read when asked, never watched
static const gsize kPictureMost = 160u * 1024 * 1024;
// past this many characters words are no link (kLinkMost in dart)
static const gsize kLinkMost = 8192;

typedef struct {
  FlMethodCall* call;
  gchar* link;
} ClipAsk;

static ClipAsk* clip_ask_new(FlMethodCall* call) {
  ClipAsk* ask = g_new0(ClipAsk, 1);
  ask->call = FL_METHOD_CALL(g_object_ref(call));
  return ask;
}

static void clip_answer(ClipAsk* ask, FlValue* result) {
  g_autoptr(FlValue) owned = result;
  fl_method_call_respond_success(ask->call, result, nullptr);
  g_object_unref(ask->call);
  g_free(ask->link);
  g_free(ask);
}

static gboolean has_target(GdkAtom* atoms, gint n, const gchar* name) {
  for (gint i = 0; i < n; i++) {
    g_autofree gchar* a = gdk_atom_name(atoms[i]);
    if (g_strcmp0(a, name) == 0) return TRUE;
  }
  return FALSE;
}

static void clip_files_got(GtkClipboard*, GtkSelectionData* data,
                           gpointer user_data) {
  ClipAsk* ask = static_cast<ClipAsk*>(user_data);
  FlValue* files = fl_value_new_list();
  const guchar* raw = data ? gtk_selection_data_get_data(data) : nullptr;
  gint n = data ? gtk_selection_data_get_length(data) : 0;
  if (raw != nullptr && n > 0) {
    g_autofree gchar* text = g_strndup(reinterpret_cast<const gchar*>(raw), n);
    g_auto(GStrv) lines = g_strsplit(text, "\n", -1);
    // gnome's list starts with copy or cut, a uri list may hold comments:
    // only local files are taken
    for (gchar** l = lines; *l != nullptr; ++l) {
      g_strstrip(*l);
      if (!g_str_has_prefix(*l, "file://")) continue;
      g_autofree gchar* path = g_filename_from_uri(*l, nullptr, nullptr);
      if (path == nullptr) continue;
      g_autofree gchar* utf8 =
          g_filename_to_utf8(path, -1, nullptr, nullptr, nullptr);
      if (utf8 != nullptr) fl_value_append_take(files, fl_value_new_string(utf8));
    }
  }
  clip_answer(ask, files);
}

static void clip_files_targets(GtkClipboard* clip, GdkAtom* atoms, gint n,
                               gpointer user_data) {
  ClipAsk* ask = static_cast<ClipAsk*>(user_data);
  const gchar* pick = nullptr;
  if (has_target(atoms, n, "x-special/gnome-copied-files")) {
    pick = "x-special/gnome-copied-files";
  } else if (has_target(atoms, n, "text/uri-list")) {
    pick = "text/uri-list";
  }
  if (pick == nullptr) {
    clip_answer(ask, fl_value_new_list());
    return;
  }
  gtk_clipboard_request_contents(clip, gdk_atom_intern(pick, FALSE),
                                 clip_files_got, ask);
}

// words that are only a link once trimmed: firefox's copy image puts the
// picture's address beside it. dart checks the link again
static gboolean lone_link(const gchar* words) {
  if (words == nullptr) return FALSE;
  g_autofree gchar* t = g_strstrip(g_strdup(words));
  gsize n = strlen(t);
  if (n == 0 || n > kLinkMost) return FALSE;
  for (const gchar* c = t; *c != '\0'; ++c) {
    if (g_ascii_isspace(*c)) return FALSE;
  }
  return g_str_has_prefix(t, "http://") || g_str_has_prefix(t, "https://");
}

static void clip_picture_got(GtkClipboard*, GtkSelectionData* data,
                             gpointer user_data) {
  ClipAsk* ask = static_cast<ClipAsk*>(user_data);
  const guchar* raw = data ? gtk_selection_data_get_data(data) : nullptr;
  gint n = data ? gtk_selection_data_get_length(data) : 0;
  if (raw == nullptr || n <= 0 || static_cast<gsize>(n) > kPictureMost) {
    clip_answer(ask, fl_value_new_null());
    return;
  }
  FlValue* got = fl_value_new_map();
  fl_value_set_string_take(got, "kind", fl_value_new_string("png"));
  fl_value_set_string_take(got, "bytes", fl_value_new_uint8_list(raw, n));
  if (ask->link != nullptr) {
    fl_value_set_string_take(got, "text", fl_value_new_string(ask->link));
  }
  clip_answer(ask, got);
}

static void clip_picture_text(GtkClipboard* clip, const gchar* text,
                              gpointer user_data) {
  ClipAsk* ask = static_cast<ClipAsk*>(user_data);
  // words beside a picture paste as words, unless only a link
  if (text != nullptr && !lone_link(text)) {
    clip_answer(ask, fl_value_new_null());
    return;
  }
  if (text != nullptr) ask->link = g_strstrip(g_strdup(text));
  gtk_clipboard_request_contents(clip, gdk_atom_intern("image/png", FALSE),
                                 clip_picture_got, ask);
}

static void clip_picture_targets(GtkClipboard* clip, GdkAtom* atoms, gint n,
                                 gpointer user_data) {
  ClipAsk* ask = static_cast<ClipAsk*>(user_data);
  // files copied in a file manager are files, not a picture
  if (atoms == nullptr || !has_target(atoms, n, "image/png") ||
      has_target(atoms, n, "x-special/gnome-copied-files") ||
      has_target(atoms, n, "text/uri-list")) {
    clip_answer(ask, fl_value_new_null());
    return;
  }
  if (gtk_targets_include_text(atoms, n)) {
    gtk_clipboard_request_text(clip, clip_picture_text, ask);
    return;
  }
  clip_picture_text(clip, nullptr, ask);
}

// "Copy picture": a png kryfo made (a qr, a cleaned picture), kept by this
// app on the clipboard until something else is copied
static gboolean set_clip_picture(FlValue* args) {
  FlValue* png = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                     ? fl_value_lookup_string(args, "png")
                     : nullptr;
  if (png == nullptr || fl_value_get_type(png) != FL_VALUE_TYPE_UINT8_LIST) {
    return FALSE;
  }
  gsize n = fl_value_get_length(png);
  if (n == 0 || n > kPictureMost) return FALSE;
  g_autoptr(GdkPixbufLoader) loader = gdk_pixbuf_loader_new_with_type("png", nullptr);
  if (loader == nullptr) return FALSE;
  gboolean ok = gdk_pixbuf_loader_write(loader, fl_value_get_uint8_list(png), n,
                                        nullptr);
  ok = gdk_pixbuf_loader_close(loader, nullptr) && ok;
  GdkPixbuf* pixbuf = ok ? gdk_pixbuf_loader_get_pixbuf(loader) : nullptr;
  if (pixbuf == nullptr) return FALSE;
  gtk_clipboard_set_image(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD), pixbuf);
  return TRUE;
}

static void desktop_call_cb(FlMethodChannel* channel, FlMethodCall* call,
                            gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;
  if (g_strcmp0(fl_method_call_get_name(call), "tray") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    make_tray(self, map_string(args, "open"), map_string(args, "quit"),
              map_string(args, "tip"));
    g_clear_pointer(&self->tray_hint, g_free);
    const gchar* hint = map_string(args, "hint");
    if (hint[0] != '\0') self->tray_hint = g_strdup(hint);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(fl_method_call_get_name(call), "noTray") == 0) {
    drop_tray(self);
    // no icon left to open a hidden window from
    if (self->window != nullptr &&
        !gtk_widget_get_visible(GTK_WIDGET(self->window))) {
      show_window(self);
    }
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else if (g_strcmp0(fl_method_call_get_name(call), "trayState") == 0) {
    g_autoptr(FlValue) shown = fl_value_new_bool(tray_shown(self));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(shown));
  } else if (g_strcmp0(fl_method_call_get_name(call), "autostart") == 0) {
    FlValue* args = fl_method_call_get_args(call);
    FlValue* on = args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP
                      ? fl_value_lookup_string(args, "on")
                      : nullptr;
    ask_portal(call,
               on != nullptr && fl_value_get_type(on) == FL_VALUE_TYPE_BOOL &&
                   fl_value_get_bool(on),
               map_string(args, "reason"));
    return;
  } else if (g_strcmp0(fl_method_call_get_name(call), "startHidden") == 0) {
    g_autoptr(FlValue) hidden = fl_value_new_bool(self->start_hidden);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(hidden));
  } else if (g_strcmp0(fl_method_call_get_name(call), "clipFiles") == 0) {
    gtk_clipboard_request_targets(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD),
                                  clip_files_targets, clip_ask_new(call));
    return;
  } else if (g_strcmp0(fl_method_call_get_name(call), "clipPicture") == 0) {
    gtk_clipboard_request_targets(gtk_clipboard_get(GDK_SELECTION_CLIPBOARD),
                                  clip_picture_targets, clip_ask_new(call));
    return;
  } else if (g_strcmp0(fl_method_call_get_name(call), "setClipPicture") == 0) {
    g_autoptr(FlValue) ok =
        fl_value_new_bool(set_clip_picture(fl_method_call_get_args(call)));
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(ok));
  } else if (g_strcmp0(fl_method_call_get_name(call), "show") == 0) {
    show_window(self);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }
  fl_method_call_respond(call, response, nullptr);
}

// the first close to the tray says kryfo keeps running there, as a
// notification, and dart hears it was said: never again
static void say_tray_hint(MyApplication* self) {
  if (self->tray_hint == nullptr) return;
  g_autoptr(GNotification) n = g_notification_new("Kryfo");
  g_notification_set_body(n, self->tray_hint);
  g_application_send_notification(G_APPLICATION(self), "tray-hint", n);
  g_clear_pointer(&self->tray_hint, g_free);
  if (self->desktop_channel != nullptr) {
    fl_method_channel_invoke_method(self->desktop_channel, "hinted", nullptr,
                                    nullptr, nullptr, nullptr);
  }
}

// with a tray the window only hides, and the app goes on receiving
static gboolean delete_cb(GtkWidget* widget, GdkEvent*, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  if (!tray_shown(self)) return FALSE;
  gtk_widget_hide(widget);
  say_tray_hint(self);
  return TRUE;
}

static void first_frame_cb(MyApplication* self, FlView* view) {
  // a hidden start stays in the tray; show_window brings it up
  if (self->start_hidden) return;
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  // a second start brings the running one forward: two processes on one
  // folder would fight over its database and its tor
  if (self->window != nullptr) {
    show_window(self);
    return;
  }
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));
  self->window = window;
  g_autofree gchar* icon = icon_path();
  if (icon != nullptr) gtk_window_set_icon_from_file(window, icon, nullptr);
  g_signal_connect(window, "delete-event", G_CALLBACK(delete_cb), self);

  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "Kryfo");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "Kryfo");
  }

  gtk_window_set_default_size(window, 1280, 720);
  // no smaller than the narrow layout still reads: a phone's width
  GdkGeometry least = {};
  least.min_width = 380;
  least.min_height = 560;
  gtk_window_set_geometry_hints(window, nullptr, &least, GDK_HINT_MIN_SIZE);

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  GdkRGBA background_color;
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->desktop_channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "kryfo/desktop", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(self->desktop_channel,
                                            desktop_call_cb, self, nullptr);

  gtk_widget_grab_focus(GTK_WIDGET(view));

  if (self->start_hidden) {
    self->hidden_timer =
        g_timeout_add_seconds(kHiddenWaitSeconds, hidden_timed_out, self);
  }
}

static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // --hidden is the runner's, the rest go to dart. in a second start it
  // changes nothing: the first one's window comes up
  GPtrArray* rest = g_ptr_array_new();
  for (gchar** a = *arguments + 1; *a != nullptr; a++) {
    if (g_strcmp0(*a, "--hidden") == 0) {
      self->start_hidden = TRUE;
    } else {
      g_ptr_array_add(rest, g_strdup(*a));
    }
  }
  g_ptr_array_add(rest, nullptr);
  self->dart_entrypoint_arguments =
      reinterpret_cast<gchar**>(g_ptr_array_free(rest, FALSE));

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

static void my_application_startup(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

static void my_application_shutdown(GApplication* application) {
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  if (self->hidden_timer != 0) {
    g_source_remove(self->hidden_timer);
    self->hidden_timer = 0;
  }
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  g_clear_pointer(&self->tray_hint, g_free);
  g_clear_object(&self->desktop_channel);
  drop_indicator(self);
  g_clear_object(&self->tray);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

// unique, so a second start raises the first. the flag's new name came in
// glib 2.74; ubuntu 22.04 has 2.72
#if GLIB_CHECK_VERSION(2, 74, 0)
#define KRYFO_APP_FLAGS G_APPLICATION_DEFAULT_FLAGS
#else
#define KRYFO_APP_FLAGS G_APPLICATION_FLAGS_NONE
#endif

MyApplication* my_application_new() {
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     KRYFO_APP_FLAGS, nullptr));
}
