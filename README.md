# Git Log Summarizer & Calendar Integration

`所有代码由 Claude 和 ChatGPT 共同完成，包括您现在看到的 README 文件，我只是稍作修改。`

![demo](https://pbs.twimg.com/media/F2sR3zcbMAAc4Ub?format=jpg&name=4096x4096)

## 项目简介

该项目旨在通过读取本地 Git 仓库的近期提交日志（commit log），利用百度文心一言 AI 对日志内容进行总结，并按项目和日期自动添加到指定日历中。

适用于需要追踪项目进展和快速获取日志摘要的开发者。

---

## 功能特点

- **自动化日志总结**：将 Git 提交日志发送至文心一言，生成精简的日志摘要。
- **日历事件集成**：按日期和项目将日志总结添加到 macOS 的日历应用中。
- **多项目支持**：支持多个 Git 仓库，按配置文件管理日历关联。
---

## 使用说明

### 1. 环境要求

- macOS 系统（支持 AppleScript 操作日历）
- Bash 环境
- 安装 `curl` 工具

### 2. 配置文件说明

项目运行依赖一个 `config.ini` 文件，配置内容如下：

```ini
[calendars]
work = 工作
life = 人生体验推进计划

[repositories]
work_repo1 = /git_path/work_repo1
work_repo2 = /git_path/work_repo2
life_repo1 = /git_path/life_repo1

[mapping]
work_repo1 = work
work_repo2 = work
life_repo1 = life

[api]
client_id = <YOUR_CLIENT_ID>
client_secret = <YOUR_CLIENT_SECRET>
```

文心一言 API KEY 在这里申请

https://console.bce.baidu.com/qianfan/ais/console/applicationConsole/application
