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

import { NodeObj, NodeStyle, RichTextSpan } from '../model/NodeObj';

interface TextMatch {
  start: number;
  end: number;
  config: RichTextSpan;
}

interface LinkTag {
  fullMatch: string;
  linkText: string;
  href: string;
  startIndex: number;
  endIndex: number;
}

export class RichTextParser {
  /**
   * 解析文本内容，自动提取a标签并转换为富文本
   * @param topic 包含HTML a标签的文本内容
   * @returns 解析后的文本片段数组
   */
  static parse(node: NodeObj): RichTextSpan[] {
    const topic = node.topic;
    if (!topic) {
      return [{ text: '' }];
    }

    // 1. 自动提取a标签并转换为富文本配置
    const autoRichText = RichTextParser.extractLinkTagsAsRichText(node);

    // 如果没有a标签，返回普通文本
    if (autoRichText.length === 0) {
      return [{ text: RichTextParser.cleanHtmlTags(topic) }];
    }

    // 2. 使用原有的匹配逻辑
    const matches: TextMatch[] = [];
    const cleanTopic = RichTextParser.cleanHtmlTags(topic); // 清理HTML标签后的纯文本

    for (const richSpan of autoRichText) {
      const searchText = richSpan.text;
      let startIndex = 0;

      while (startIndex < cleanTopic.length) {
        const index = cleanTopic.indexOf(searchText, startIndex);
        if (index === -1) break;

        const match: TextMatch = {
          start: index,
          end: index + searchText.length,
          config: {
            text: searchText,
            style: richSpan.style,
            isLink: richSpan.isLink,
            originText: richSpan.originText,
          }
        };

        matches.push(match);
        startIndex = index + searchText.length;
      }
    }

    if (matches.length === 0) {
      return [{ text: cleanTopic }];
    }

    // 3. 排序并构建结果数组
    matches.sort((a, b) => a.start - b.start);
    const result: RichTextSpan[] = [];
    let lastIndex = 0;

    for (const match of matches) {
      if (match.start > lastIndex) {
        result.push({ text: cleanTopic.substring(lastIndex, match.start) });
      }
      result.push(match.config);
      lastIndex = match.end;
    }

    if (lastIndex < cleanTopic.length) {
      result.push({ text: cleanTopic.substring(lastIndex) });
    }

    return result;
  }

  /**
   * 从文本中提取a标签并转换为RichTextSpan配置
   */
  private static extractLinkTagsAsRichText(node: NodeObj): RichTextSpan[] {
    const text = node.topic;
    let linkStyle: NodeStyle;
    const linkTags = RichTextParser.extractLinkTags(text);
    if(!node.linkStyle) {
      node.linkStyle = {
        color: '#007DFF',
      };
    }
    if(!node.linkStyle.color) {
      node.linkStyle.color = '#007DFF';
    }
    return linkTags.map((linkTag: LinkTag) => {
      const richTextSpan: RichTextSpan = {
        text: linkTag.linkText,
        style: node.linkStyle,
        isLink: true,
        originText: linkTag.fullMatch
      };
      return richTextSpan;
    });
  }

  /**
   * 从文本中提取所有a标签信息
   */
  private static extractLinkTags(text: string): LinkTag[] {
    const linkTags: LinkTag[] = [];
    const aTagRegex = /<a\s*(?:\s+[^>]*?href=('|")([^'"]*)\1)?[^>]*>([^<]*)<\/a>/gi;

    let match: RegExpExecArray | null;
    let currentIndex = 0;

    while ((match = aTagRegex.exec(text)) !== null) {
      const fullMatch: string = match[0];
      const href: string = match[2] || '';
      const linkText: string = match[3];
      const startIndex: number = match.index;
      const endIndex: number = startIndex + fullMatch.length;

      linkTags.push({
        fullMatch,
        linkText,
        href,
        startIndex,
        endIndex
      });

      // 避免无限循环，确保索引前进
      if (match.index === currentIndex) {
        aTagRegex.lastIndex++;
      }
      currentIndex = match.index;
    }
    return linkTags;
  }

  /**
   * 清理HTML标签，返回纯文本内容
   */
  static cleanHtmlTags(text: string): string {
    return text.replace(/<[^>]*>/g, '');
  }
}