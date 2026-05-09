# active_skills_install
用于安装active_skills 目录下的skills
用法:
  sh active_skills_install/active_skills_install.sh                     安装 active_skills 下全部 skills
  sh active_skills_install/active_skills_install.sh all                 安装 active_skills 下全部 skills
  sh active_skills_install/active_skills_install.sh <skill-name|path>  安装单个 skill
  sh active_skills_install/active_skills_install.sh list                列出可安装的 skills
  sh active_skills_install/active_skills_install.sh status [selector]   查看一个或全部 skills 的安装状态
  sh active_skills_install/active_skills_install.sh help                查看帮助

selector 支持以下任一形式:
  - SKILL.md 中的 name，例如 ui-screen-generator
  - 相对 active_skills 的路径，例如 active-build-script/skill/active-build
  - skill 目录名，例如 active-jira

环境变量:
  ACTIVE_SKILLS_ROOT         active_skills 根目录；默认取脚本所在目录的上一级目录
  AGENTS_INSTALL_DIR         Agents/Copilot 用户级 skills 目录；默认 ~/.agents/skills
  CODEX_INSTALL_DIR          Codex 用户级 skills 目录；默认 ~/.codex/skills

说明:
  - 安装结果是软链接，源码仍保留在 active_skills 目录下维护。
  - GitHub Copilot/VS Code Agents 的用户级 skill 目录使用 ~/.agents/skills。
  - Codex 的用户级 skill 目录使用 ~/.codex/skills。
