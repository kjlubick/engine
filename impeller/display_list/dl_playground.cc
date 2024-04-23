// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/display_list/dl_playground.h"

#include "flutter/testing/testing.h"
#include "impeller/aiks/aiks_context.h"
#include "impeller/display_list/dl_dispatcher.h"
#include "impeller/typographer/backends/skia/typographer_context_skia.h"
#include "third_party/imgui/imgui.h"
#include "third_party/skia/include/core/SkData.h"
#include "third_party/skia/include/core/SkFontMgr.h"
#include "third_party/skia/include/core/SkTypeface.h"
#include "txt/platform.h"

#define ENABLE_EXPERIMENTAL_CANVAS false

namespace impeller {

DlPlayground::DlPlayground() = default;

DlPlayground::~DlPlayground() = default;

bool DlPlayground::OpenPlaygroundHere(flutter::DisplayListBuilder& builder) {
  return OpenPlaygroundHere(builder.Build());
}

bool DlPlayground::OpenPlaygroundHere(sk_sp<flutter::DisplayList> list) {
  return OpenPlaygroundHere([&list]() { return list; });
}

bool DlPlayground::OpenPlaygroundHere(DisplayListPlaygroundCallback callback) {
  if (!switches_.enable_playground) {
    return true;
  }

  AiksContext context(GetContext(), TypographerContextSkia::Make());
  if (!context.IsValid()) {
    return false;
  }
  return Playground::OpenPlaygroundHere(
      [&context, &callback](RenderTarget& render_target) -> bool {
        static bool wireframe = false;
        if (ImGui::IsKeyPressed(ImGuiKey_Z)) {
          wireframe = !wireframe;
          context.GetContentContext().SetWireframe(wireframe);
        }

        auto list = callback();

#if ENABLE_EXPERIMENTAL_CANVAS
        TextFrameDispatcher collector(context.GetContentContext(), Matrix());
        list->Dispatch(collector);

        ExperimentalDlDispatcher impeller_dispatcher(
            context.GetContentContext(), render_target, IRect::MakeMaximum());
        list->Dispatch(impeller_dispatcher);
        impeller_dispatcher.FinishRecording();
        context.GetContentContext().GetTransientsBuffer().Reset();
        context.GetContentContext().GetLazyGlyphAtlas()->ResetTextFrames();
        return true;
#else
        DlDispatcher dispatcher;
        list->Dispatch(dispatcher);
        auto picture = dispatcher.EndRecordingAsPicture();

        return context.Render(picture, render_target, true);
#endif
      });
}

SkFont DlPlayground::CreateTestFontOfSize(SkScalar scalar) {
  static constexpr const char* kTestFontFixture = "Roboto-Regular.ttf";
  auto mapping = flutter::testing::OpenFixtureAsSkData(kTestFontFixture);
  FML_CHECK(mapping);
  sk_sp<SkFontMgr> font_mgr = txt::GetDefaultFontManager();
  return SkFont{font_mgr->makeFromData(mapping), scalar};
}

SkFont DlPlayground::CreateTestFont() {
  return CreateTestFontOfSize(50);
}

}  // namespace impeller
