/*
 * Copyright (C) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import { UIContext } from '@kit.ArkUI';
import { GlobalContext } from '../utils/GlobalContext';
import { TextSize } from '../model/NodeObj';

export class TextMeasureUtils {
  private static instance: TextMeasureUtils;

  // 私有构造函数，确保单例模式
  private constructor() {
  }

  // 获取单例实例
  public static getInstance(): TextMeasureUtils {
    if (!TextMeasureUtils.instance) {
      TextMeasureUtils.instance = new TextMeasureUtils();
    }
    return TextMeasureUtils.instance;
  }

  // 测量文本尺寸
  public measureText(textContent: string, fontSize: Length = 20, maxWidth: number = 200): TextSize {
    const uiContext: UIContext | null = GlobalContext.getInstance().getUiContext()!;
    // 先测量文本的实际宽度（不限制宽度）
    const unconstrainedSize = uiContext.getMeasureUtils().measureTextSize({
      textContent,
      fontSize
    });
    const actualWidth = uiContext!.px2vp(Number(unconstrainedSize.width));
    const actualHeight = uiContext!.px2vp(Number(unconstrainedSize.height));
    const finalWidth = Math.min(actualWidth, maxWidth);
    let finalHeight = actualHeight;
    if (actualWidth > maxWidth) {
      const constrainedSize = uiContext.getMeasureUtils().measureTextSize({
        textContent,
        fontSize,
        constraintWidth: maxWidth
      });
      finalHeight = uiContext!.px2vp(Number(constrainedSize.height));
    }
    return {
      width: finalWidth,
      height: finalHeight
    };
  }
}