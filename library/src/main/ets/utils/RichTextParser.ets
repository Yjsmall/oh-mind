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
   * 解析文本内容，支持a标签自动解析和手动richText配置两种模式
   * @param node 节点对象
   * @returns 解析后的文本片段数组
   */
  static parse(node: NodeObj): RichTextSpan[] {
    const topic = node.topic;
    if (!topic) {
      return [{ text: '' }];
    }

    // 模式1：如果存在richText配置，直接使用richText模式
    if (node.richText && node.richText.length > 0) {
      return RichTextParser.parseWithRichText(node);
    }

    // 模式2：如果文本包含a标签，使用a标签解析模式
    const hasLinkTags = RichTextParser.hasLinkTags(topic);
    if (hasLinkTags) {
      return RichTextParser.parseWithLinkTags(node);
    }

    // 模式3：普通文本模式
    return [{ text: RichTextParser.cleanHtmlTags(topic) }];
  }

  /**
   * 使用richText配置模式进行解析
   */
  private static parseWithRichText(node: NodeObj): RichTextSpan[] {
    const topic = node.topic;
    const cleanTopic = RichTextParser.cleanHtmlTags(topic);

    // 如果richText配置存在，直接使用配置构建结果
    const matches: TextMatch[] = [];

    for (const richSpan of node.richText!) {
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
            isLink: true,
            onClick: richSpan.onClick
          }
        };

        matches.push(match);
        startIndex = index + searchText.length;
      }
    }

    if (matches.length === 0) {
      return [{ text: cleanTopic }];
    }

    // 排序并构建结果数组
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
   * 使用a标签解析模式
   */
  private static parseWithLinkTags(node: NodeObj): RichTextSpan[] {
    const topic = node.topic;
    const autoRichText = RichTextParser.extractLinkTagsAsRichText(node);

    // 使用原有的匹配逻辑
    const matches: TextMatch[] = [];
    const cleanTopic = RichTextParser.cleanHtmlTags(topic);

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
            isLink: true,
            originText: richSpan.originText,
            onClick: richSpan.onClick,
          }
        };

        matches.push(match);
        startIndex = index + searchText.length;
      }
    }

    if (matches.length === 0) {
      return [{ text: cleanTopic }];
    }

    // 排序并构建结果数组
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
   * 检查文本是否包含a标签
   */
  private static hasLinkTags(text: string): boolean {
    const aTagRegex = /<a\s*(?:\s+[^>]*?href=('|")([^'"]*)\1)?[^>]*>([^<]*)<\/a>/gi;
    return aTagRegex.test(text);
  }

  /**
   * 从文本中提取a标签并转换为RichTextSpan配置
   */
  private static extractLinkTagsAsRichText(node: NodeObj): RichTextSpan[] {
    const text = node.topic;
    const linkTags = RichTextParser.extractLinkTags(text);

    // 设置默认链接样式
    if (!node.linkStyle) {
      node.linkStyle = {
        color: '#007DFF',
      };
    }
    if (!node.linkStyle.color) {
      node.linkStyle.color = '#007DFF';
    }

    return linkTags.map((linkTag: LinkTag) => {
      const richTextSpan: RichTextSpan = {
        text: linkTag.linkText,
        style: node.linkStyle,
        isLink: true,
        originText: linkTag.fullMatch,
        onClick: () => {
          // 触发节点的 onLinkClick 回调
          if (node.onLinkClick) {
            node.onLinkClick(linkTag.fullMatch);
          }
        }
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