#include "flutter_window.h"

#include <optional>
#include <windowsx.h>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Intercept WM_NCHITTEST to return HTMAXBUTTON over the maximize button area,
  // enabling Windows snap layouts on custom title bars.
  // Button layout (Flutter custom title bar): each button is 46x40 logical px,
  // order from right: [close][maximize][minimize]
  if (message == WM_NCHITTEST) {
    POINT cursor = {GET_X_LPARAM(lparam), GET_Y_LPARAM(lparam)};
    RECT window_rect;
    GetWindowRect(hwnd, &window_rect);

    UINT dpi = GetDpiForWindow(hwnd);
    // Match Flutter _WindowButton: width=46, height=40 (logical pixels)
    int btn_width = MulDiv(46, dpi, 96);
    int btn_height = MulDiv(40, dpi, 96);

    // Maximize button is second from right (close is rightmost)
    RECT maximize_rect = {
        window_rect.right - btn_width * 2,
        window_rect.top,
        window_rect.right - btn_width,
        window_rect.top + btn_height,
    };

    if (PtInRect(&maximize_rect, cursor)) {
      return HTMAXBUTTON;
    }
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
