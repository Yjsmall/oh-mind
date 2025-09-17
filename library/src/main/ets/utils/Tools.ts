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

export function generateId(): string {
  const timestamp = new Date().getTime().toString(16);
  const randomPart = Math.random().toString(16).slice(2);
  return (timestamp + randomPart).slice(0, 16);
}

/**
 * 深拷贝方法
 * @param obj 要拷贝的对象
 * @param cache 用于处理循环引用的缓存Map
 * @returns 深拷贝后的对象
 */
export function deepClone<T>(obj: T, cache = new WeakMap<any, any>()): T {
  // 处理基本数据类型和null
  if (obj === null || typeof obj !== 'object') {
    return obj;
  }

  // 处理函数 - 直接返回原函数引用
  if (typeof obj === 'function') {
    return obj;
  }

  // 处理日期对象
  if (obj instanceof Date) {
    return new Date(obj.getTime()) as unknown as T;
  }

  // 处理正则表达式
  if (obj instanceof RegExp) {
    return new RegExp(obj.source, obj.flags) as unknown as T;
  }

  // 处理Map
  if (obj instanceof Map) {
    const result = new Map();
    cache.set(obj, result);
    obj.forEach((value, key) => {
      result.set(deepClone(key, cache), deepClone(value, cache));
    });
    return result as unknown as T;
  }

  // 处理Set
  if (obj instanceof Set) {
    const result = new Set();
    cache.set(obj, result);
    obj.forEach(value => {
      result.add(deepClone(value, cache));
    });
    return result as unknown as T;
  }

  // 处理ArrayBuffer
  if (obj instanceof ArrayBuffer) {
    return obj.slice(0) as unknown as T;
  }

  // 处理TypedArray
  if (ArrayBuffer.isView(obj)) {
    return (obj as any).slice() as T;
  }

  // 检查循环引用
  if (cache.has(obj)) {
    return cache.get(obj);
  }

  // 处理数组
  if (Array.isArray(obj)) {
    const result: any[] = [];
    cache.set(obj, result);
    for (let i = 0; i < obj.length; i++) {
      result[i] = deepClone(obj[i], cache);
    }
    return result as unknown as T;
  }

  // 处理普通对象
  if (typeof obj === 'object') {
    // 获取对象的所有属性（包括不可枚举和Symbol属性）
    const allKeys = [
      ...Object.getOwnPropertyNames(obj),
      ...Object.getOwnPropertySymbols(obj)
    ];

    const result: any = {};
    cache.set(obj, result);

    for (const key of allKeys) {
      // 跳过原型链上的属性
      if (!obj.hasOwnProperty(key)) {
        continue;
      }

      const descriptor = Object.getOwnPropertyDescriptor(obj, key);

      // 处理getter/setter
      if (descriptor && (descriptor.get || descriptor.set)) {
        Object.defineProperty(result, key, descriptor);
      } else {
        const value = (obj as any)[key];
        result[key] = deepClone(value, cache);
      }
    }

    // 复制原型
    Object.setPrototypeOf(result, Object.getPrototypeOf(obj));
    return result;
  }

  return obj;
}

/**
 * 深拷贝方法
 * @param color 颜色值
 * @returns 是否为白色
 */
export function isColorWhite(color: string): boolean {
  try {
    const normalizedColor = color.trim().toLowerCase();
    if (normalizedColor === '#fff' ||
      normalizedColor === '#ffffff' ||
      normalizedColor === 'white' ||
      normalizedColor === 'rgb(255,255,255)' ||
      normalizedColor === 'rgba(255,255,255,1)') {
      return true;
    }
    let r = 255, g = 255, b = 255;

    if (normalizedColor.startsWith('#')) {
      // 处理十六进制颜色
      const hex = normalizedColor.replace('#', '');
      if (hex.length === 3) {
        r = parseInt(hex[0] + hex[0], 16);
        g = parseInt(hex[1] + hex[1], 16);
        b = parseInt(hex[2] + hex[2], 16);
      } else if (hex.length === 6 || hex.length === 8) {
        r = parseInt(hex.substring(0, 2), 16);
        g = parseInt(hex.substring(2, 4), 16);
        b = parseInt(hex.substring(4, 6), 16);
      }
    } else if (normalizedColor.startsWith('rgb')) {
      const match = normalizedColor.match(/rgba?\((\d+),\s*(\d+),\s*(\d+)(,\s*[\d.]+)?\)/);
      if (match) {
        r = parseInt(match[1]);
        g = parseInt(match[2]);
        b = parseInt(match[3]);
      }
    }

    const threshold = 240;
    return r >= threshold && g >= threshold && b >= threshold;

  } catch (e) {
    console.warn('颜色解析失败:', color, e);
    return false;
  }
}