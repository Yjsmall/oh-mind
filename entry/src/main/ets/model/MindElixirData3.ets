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

import { MindElixirData } from '@ohos/mind-elixir';

const mindElixirData: MindElixirData = {
  nodeData: {
    id: "root",
    topic: "项目规划",
    expanded: true,
    children: [
      {
        topic: "需求分析",
        id: "requirement-analysis",
        expanded: true,
        children: [
          {
            topic: "用户调研",
            id: "user-research",
            expanded: true,
            style: {
              background: '#e3f2fd',
              color: '#1565c0'
            }
          },
          {
            topic: "竞品分析",
            id: "competitor-analysis",
            expanded: true,
            style: {
              background: '#f3e5f5',
              color: '#7b1fa2'
            }
          },
          {
            topic: "功能清单",
            id: "feature-list",
            expanded: true,
            style: {
              background: '#e8f5e8',
              color: '#2e7d32'
            }
          }
        ]
      },
      {
        topic: "技术架构",
        id: "technical-architecture",
        expanded: true,
        children: [
          {
            topic: "前端技术栈",
            id: "frontend-tech",
            expanded: true,
            style: {
              background: '#fff3e0',
              color: '#ef6c00'
            }
          },
          {
            topic: "后端技术栈",
            id: "backend-tech",
            expanded: true,
            style: {
              background: '#e0f7fa',
              color: '#00838f'
            }
          },
          {
            topic: "数据库设计",
            id: "database-design",
            expanded: true,
            style: {
              background: '#fbe9e7',
              color: '#d84315'
            }
          }
        ]
      },
      {
        topic: "开发计划",
        id: "development-plan",
        expanded: true,
        children: [
          {
            topic: "第一阶段",
            id: "phase1",
            expanded: true,
            style: {
              background: '#f1f8e9',
              color: '#558b2f'
            }
          },
          {
            topic: "第二阶段",
            id: "phase2",
            expanded: true,
            style: {
              background: '#e8eaf6',
              color: '#283593'
            }
          },
          {
            topic: "第三阶段",
            id: "phase3",
            expanded: true,
            style: {
              background: '#ffebee',
              color: '#c62828'
            }
          }
        ]
      },
      {
        topic: "团队分工",
        id: "team-division",
        expanded: true,
        children: [
          {
            topic: "前端开发",
            id: "frontend-team",
            expanded: true,
            style: {
              background: '#fff8e1',
              color: '#ff8f00'
            }
          },
          {
            topic: "后端开发",
            id: "backend-team",
            expanded: true,
            style: {
              background: '#e0f2f1',
              color: '#00695c'
            }
          },
          {
            topic: "测试团队",
            id: "testing-team",
            expanded: true,
            style: {
              background: '#fce4ec',
              color: '#ad1457'
            }
          }
        ]
      },
      {
        topic: "资源分配",
        id: "resource-allocation",
        expanded: true,
        children: [
          {
            topic: "人力资源",
            id: "human-resources",
            expanded: true,
            style: {
              background: '#e8f5e8',
              color: '#2e7d32'
            }
          },
          {
            topic: "硬件资源",
            id: "hardware-resources",
            expanded: true,
            style: {
              background: '#e3f2fd',
              color: '#1565c0'
            }
          },
          {
            topic: "时间安排",
            id: "time-schedule",
            expanded: true,
            style: {
              background: '#f3e5f5',
              color: '#7b1fa2'
            }
          }
        ]
      },
      {
        topic: "风险管理",
        id: "risk-management",
        expanded: true,
        children: [
          {
            topic: "技术风险",
            id: "technical-risks",
            expanded: true,
            style: {
              background: '#ffebee',
              color: '#c62828'
            }
          },
          {
            topic: "进度风险",
            id: "schedule-risks",
            expanded: true,
            style: {
              background: '#fff3e0',
              color: '#ef6c00'
            }
          },
          {
            topic: "资源风险",
            id: "resource-risks",
            expanded: true,
            style: {
              background: '#e0f7fa',
              color: '#00838f'
            }
          }
        ]
      },
      {
        topic: "质量保障",
        id: "quality-assurance",
        expanded: true,
        children: [
          {
            topic: "代码审查",
            id: "code-review",
            expanded: true,
            style: {
              background: '#f1f8e9',
              color: '#558b2f'
            }
          },
          {
            topic: "测试策略",
            id: "testing-strategy",
            expanded: true,
            style: {
              background: '#e8eaf6',
              color: '#283593'
            }
          },
          {
            topic: "性能优化",
            id: "performance-optimization",
            expanded: true,
            style: {
              background: '#fff8e1',
              color: '#ff8f00'
            }
          }
        ]
      },
      {
        topic: "部署上线",
        id: "deployment",
        expanded: true,
        children: [
          {
            topic: "生产环境",
            id: "production-env",
            expanded: true,
            style: {
              background: '#e0f2f1',
              color: '#00695c',
              border: {
                width: 2,
                radius: 15,
                color: '#1976d2'
              }
            }
          },
          {
            topic: "监控系统",
            id: "monitoring-system",
            expanded: true,
            style: {
              background: '#fce4ec',
              color: '#ad1457',
              border: {
                width: 2,
                radius: 15,
                color: '#1976d2'
              }
            }
          },
          {
            topic: "备份策略",
            id: "backup-strategy",
            expanded: true,
            style: {
              background: '#fbe9e7',
              color: '#d84315'
            }
          }
        ]
      }
    ],
    style: {
      background: '#2196f3',
      color: '#ffffff',
      fontWeight: 'bold',
      fontSize: 28,
      padding: 20,
      border: {
        width: 2,
        radius: 15,
        color: '#1976d2'
      }
    }
  },
};

export default mindElixirData;