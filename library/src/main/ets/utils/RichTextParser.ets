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

import { RichTextSpan } from '../model/NodeObj';

interface TextMatch {
  start: number;
  end: number;
  config: RichTextSpan;
}

export class RichTextParser {
  /**
   * 解析富文本配置并生成文本片段数组
   * @param topic 完整的文本内容
   * @param richText 富文本配置数组
   * @returns 解析后的文本片段数组
   */
  static parse(topic: string, richText?: RichTextSpan[]): RichTextSpan[] {
    if (!richText || richText.length === 0) {
      return [{ text: topic }];
    }
    const matches: TextMatch[] = [];
    for (const richSpan of richText) {
      const searchText = richSpan.text;
      let startIndex = 0;

      while (startIndex < topic.length) {
        const index = topic.indexOf(searchText, startIndex);
        if (index === -1) break;
        const match: TextMatch = {
          start: index,
          end: index + searchText.length,
          config: {
            text: searchText,
            style: richSpan.style,
            onClick: richSpan.onClick
          }
        };

        matches.push(match);

        startIndex = index + searchText.length;
      }
    }

    if (matches.length === 0) {
      return [{ text: topic }];
    }
    matches.sort((a, b) => a.start - b.start);
    const result: RichTextSpan[] = [];
    let lastIndex = 0;

    for (const match of matches) {
      if (match.start > lastIndex) {
        result.push({ text: topic.substring(lastIndex, match.start) });
      }
      result.push(match.config);
      lastIndex = match.end;
    }
    if (lastIndex < topic.length) {
      result.push({ text: topic.substring(lastIndex) });
    }
    return result;
  }
}