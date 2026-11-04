// desktop_drop 0.8.4, cut down for kryfo: see pubspec.yaml
#include "include/desktop_drop/desktop_drop_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <stdlib.h>
#include <string.h>

#define DESKTOP_DROP_PLUGIN(obj)                                     \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), desktop_drop_plugin_get_type(), \
                              DesktopDropPlugin))

struct _DesktopDropPlugin {
  GObject parent_instance;
};

static gboolean isKDE = FALSE;
static gboolean ignoreNext = FALSE;

G_DEFINE_TYPE(DesktopDropPlugin, desktop_drop_plugin, g_object_get_type())

// the files as paths. gtk reads a uri list, and a portal transfer key from a
// sandboxed source, into uris; anything not a local file is left out
static void on_drag_data_received(GtkWidget *widget,
                                  GdkDragContext *drag_context, gint x, gint y,
                                  GtkSelectionData *sdata, guint info,
                                  guint time, gpointer user_data) {
  auto *channel = static_cast<FlMethodChannel *>(user_data);
  g_autoptr(FlValue) paths = fl_value_new_list();
  gchar **uris = gtk_selection_data_get_uris(sdata);
  if (uris != nullptr) {
    for (gchar **u = uris; *u != nullptr; u++) {
      g_autofree gchar *path = g_filename_from_uri(*u, nullptr, nullptr);
      // dart reads the name as utf-8: one that is not could not be opened
      if (path != nullptr && g_utf8_validate(path, -1, nullptr)) {
        fl_value_append_take(paths, fl_value_new_string(path));
      }
    }
    g_strfreev(uris);
  }
  g_autoptr(FlValue) args = fl_value_new_list();
  fl_value_append(args, paths);
  fl_value_append_take(args, fl_value_new_float(double(x)));
  fl_value_append_take(args, fl_value_new_float(double(y)));
  fl_method_channel_invoke_method(channel, "dropped", args, nullptr, nullptr,
                                  nullptr);
}

static gboolean on_drag_motion(GtkWidget *widget, GdkDragContext *drag_context,
                               gint x, gint y, guint time,
                               gpointer user_data) {
  if (ignoreNext) {
    ignoreNext = FALSE;
    return TRUE;
  }
  auto *channel = static_cast<FlMethodChannel *>(user_data);
  g_autoptr(FlValue) args = fl_value_new_list();
  fl_value_append_take(args, fl_value_new_float(double(x)));
  fl_value_append_take(args, fl_value_new_float(double(y)));
  fl_method_channel_invoke_method(channel, "updated", args, nullptr, nullptr,
                                  nullptr);
  return TRUE;
}

static void on_drag_leave(GtkWidget *widget, GdkDragContext *drag_context,
                          guint time, gpointer user_data) {
  auto *channel = static_cast<FlMethodChannel *>(user_data);
  fl_method_channel_invoke_method(channel, "exited", nullptr, nullptr, nullptr,
                                  nullptr);
}

static void desktop_drop_plugin_dispose(GObject *object) {
  G_OBJECT_CLASS(desktop_drop_plugin_parent_class)->dispose(object);
}

static void desktop_drop_plugin_class_init(DesktopDropPluginClass *klass) {
  G_OBJECT_CLASS(klass)->dispose = desktop_drop_plugin_dispose;
}

static void desktop_drop_plugin_init(DesktopDropPlugin *self) {
  const char *desktopEnv = getenv("XDG_CURRENT_DESKTOP");
  if (desktopEnv) {
    g_autofree gchar *lower = g_ascii_strdown(desktopEnv, -1);
    if (strcmp(lower, "kde") == 0 || strcmp(lower, "plasma") == 0) {
      isKDE = TRUE;
    }
  }
}

// kde sends a stray motion as the window takes focus
static gboolean on_focus_in_event(GtkWidget *widget, GdkEventFocus *event,
                                  gpointer user_data) {
  if (isKDE) {
    ignoreNext = TRUE;
  }
  return FALSE;
}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call,
                           gpointer user_data) {
  fl_method_call_respond_not_implemented(method_call, nullptr);
}

void desktop_drop_plugin_register_with_registrar(FlPluginRegistrar *registrar) {
  DesktopDropPlugin *plugin = DESKTOP_DROP_PLUGIN(
      g_object_new(desktop_drop_plugin_get_type(), nullptr));

  FlView *fl_view = fl_plugin_registrar_get_view(registrar);
  if (fl_view == nullptr) {
    g_object_unref(plugin);
    return;
  }
  GtkWidget *view = GTK_WIDGET(fl_view);
  // file uris only, copied: gtk adds the portal's targets itself in a
  // sandbox. the app draws its own hover, so no highlight
  gtk_drag_dest_set(view,
                    static_cast<GtkDestDefaults>(GTK_DEST_DEFAULT_MOTION |
                                                 GTK_DEST_DEFAULT_DROP),
                    nullptr, 0, GDK_ACTION_COPY);
  gtk_drag_dest_add_uri_targets(view);

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel *channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "desktop_drop", FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_signal_connect(view, "drag-motion", G_CALLBACK(on_drag_motion), channel);
  g_signal_connect(view, "drag-data-received",
                   G_CALLBACK(on_drag_data_received), channel);
  g_signal_connect(view, "drag-leave", G_CALLBACK(on_drag_leave), channel);
  g_signal_connect(view, "focus-in-event", G_CALLBACK(on_focus_in_event),
                   nullptr);

  g_object_unref(plugin);
}
