// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "impeller/entity/entity_pass_clip_stack.h"
#include "impeller/entity/contents/clip_contents.h"
#include "impeller/entity/contents/content_context.h"
#include "impeller/entity/entity.h"

namespace impeller {

EntityPassClipStack::EntityPassClipStack(const Rect& initial_coverage_rect) {
  subpass_state_.push_back(SubpassState{
      .clip_coverage =
          {
              {ClipCoverageLayer{
                  .coverage = initial_coverage_rect,
                  .clip_height = 0,
              }},
          },
  });
}

std::optional<Rect> EntityPassClipStack::CurrentClipCoverage() const {
  return subpass_state_.back().clip_coverage.back().coverage;
}

bool EntityPassClipStack::HasCoverage() const {
  return !subpass_state_.back().clip_coverage.empty();
}

void EntityPassClipStack::PushSubpass(std::optional<Rect> subpass_coverage,
                                      size_t clip_height) {
  subpass_state_.push_back(SubpassState{
      .clip_coverage =
          {
              ClipCoverageLayer{.coverage = subpass_coverage,
                                .clip_height = clip_height},
          },
  });
}

void EntityPassClipStack::PopSubpass() {
  subpass_state_.pop_back();
}

const std::vector<ClipCoverageLayer>
EntityPassClipStack::GetClipCoverageLayers() const {
  return subpass_state_.back().clip_coverage;
}

EntityPassClipStack::ClipStateResult EntityPassClipStack::ApplyClipState(
    Contents::ClipCoverage global_clip_coverage,
    Entity& entity,
    size_t clip_height_floor,
    Point global_pass_position) {
  ClipStateResult result = {.should_render = false, .clip_did_change = false};

  auto& subpass_state = GetCurrentSubpassState();
  switch (global_clip_coverage.type) {
    case Contents::ClipCoverage::Type::kNoChange:
      break;
    case Contents::ClipCoverage::Type::kAppend: {
      auto op = CurrentClipCoverage();

      // Compute the previous clip height.
      size_t previous_clip_height = 0;
      if (!subpass_state.clip_coverage.empty()) {
        previous_clip_height = subpass_state.clip_coverage.back().clip_height;
      } else {
        // If there is no clip coverage, then the previous clip height is the
        // clip height floor.
        previous_clip_height = clip_height_floor;
      }

      subpass_state.clip_coverage.push_back(
          ClipCoverageLayer{.coverage = global_clip_coverage.coverage,
                            .clip_height = previous_clip_height + 1});
      result.clip_did_change = true;

      FML_DCHECK(subpass_state.clip_coverage.back().clip_height ==
                 subpass_state.clip_coverage.front().clip_height +
                     subpass_state.clip_coverage.size() - 1);

      if (!op.has_value()) {
        // Running this append op won't impact the clip buffer because the
        // whole screen is already being clipped, so skip it.
        return result;
      }
    } break;
    case Contents::ClipCoverage::Type::kRestore: {
      ClipRestoreContents* restore_contents =
          reinterpret_cast<ClipRestoreContents*>(entity.GetContents().get());
      size_t restore_height = restore_contents->GetRestoreHeight();

      if (subpass_state.clip_coverage.back().clip_height <= restore_height) {
        // Drop clip restores that will do nothing.
        return result;
      }

      auto restoration_index =
          restore_height - subpass_state.clip_coverage.front().clip_height;
      FML_DCHECK(restoration_index < subpass_state.clip_coverage.size());

      // We only need to restore the area that covers the coverage of the
      // clip rect at target height + 1.
      std::optional<Rect> restore_coverage =
          (restoration_index + 1 < subpass_state.clip_coverage.size())
              ? subpass_state.clip_coverage[restoration_index + 1].coverage
              : std::nullopt;
      if (restore_coverage.has_value()) {
        // Make the coverage rectangle relative to the current pass.
        restore_coverage = restore_coverage->Shift(-global_pass_position);
      }
      subpass_state.clip_coverage.resize(restoration_index + 1);
      result.clip_did_change = true;

      // Skip all clip restores when stencil-then-cover is enabled.
      if (subpass_state.clip_coverage.back().coverage.has_value()) {
        RecordEntity(entity, global_clip_coverage.type, Rect());
      }
      return result;

    } break;
  }

#ifdef IMPELLER_ENABLE_CAPTURE
  {
    auto element_entity_coverage = entity.GetCoverage();
    if (element_entity_coverage.has_value()) {
      element_entity_coverage =
          element_entity_coverage->Shift(global_pass_position);
      entity.GetCapture().AddRect("Coverage", *element_entity_coverage,
                                  {.readonly = true});
    }
  }
#endif

  RecordEntity(entity, global_clip_coverage.type,
               subpass_state.clip_coverage.back().coverage);

  result.should_render = true;
  return result;
}

void EntityPassClipStack::RecordEntity(const Entity& entity,
                                       Contents::ClipCoverage::Type type,
                                       std::optional<Rect> clip_coverage) {
  auto& subpass_state = GetCurrentSubpassState();
  switch (type) {
    case Contents::ClipCoverage::Type::kNoChange:
      return;
    case Contents::ClipCoverage::Type::kAppend:
      subpass_state.rendered_clip_entities.push_back(
          {.entity = entity.Clone(), .clip_coverage = clip_coverage});
      break;
    case Contents::ClipCoverage::Type::kRestore:
      if (!subpass_state.rendered_clip_entities.empty()) {
        subpass_state.rendered_clip_entities.pop_back();
      }
      break;
  }
}

EntityPassClipStack::SubpassState&
EntityPassClipStack::GetCurrentSubpassState() {
  return subpass_state_.back();
}

const std::vector<EntityPassClipStack::ReplayResult>&
EntityPassClipStack::GetReplayEntities() const {
  return subpass_state_.back().rendered_clip_entities;
}

}  // namespace impeller
