#!/usr/bin/env sh
set -eu

ACTIVE_SKILLS_ROOT="${ACTIVE_SKILLS_ROOT:-}"
AGENTS_INSTALL_DIR="${AGENTS_INSTALL_DIR:-$HOME/.agents/skills}"
CODEX_INSTALL_DIR="${CODEX_INSTALL_DIR:-$HOME/.codex/skills}"

say() {
  printf '%s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

script_dir() {
  _src="$0"
  while [ -h "$_src" ]; do
    _dir="$(CDPATH= cd -- "$(dirname -- "$_src")" && pwd)"
    _link="$(readlink "$_src")"
    case "$_link" in
      /*) _src="$_link" ;;
      *) _src="$_dir/$_link" ;;
    esac
  done
  CDPATH= cd -- "$(dirname -- "$_src")" && pwd
}

parent_dir() {
  CDPATH= cd -- "$(dirname -- "$1")" && pwd
}

expand_user_path() {
  case "$1" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s/%s\n' "$HOME" "${1#~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

resolve_existing_dir() {
  _path="$(expand_user_path "$1")"
  [ -d "$_path" ] || die "目录不存在：$_path"
  CDPATH= cd -- "$_path" && pwd
}

resolve_target_dir() {
  _path="$(expand_user_path "$1")"
  case "$_path" in
    /*) printf '%s\n' "$_path" ;;
    *) printf '%s/%s\n' "$PWD" "$_path" ;;
  esac
}

resolve_active_skills_root() {
  if [ -n "$ACTIVE_SKILLS_ROOT" ]; then
    ACTIVE_SKILLS_ROOT="$(resolve_existing_dir "$ACTIVE_SKILLS_ROOT")"
  else
    ACTIVE_SKILLS_ROOT="$(parent_dir "$(script_dir)")"
  fi

  _skill_count="$(find "$ACTIVE_SKILLS_ROOT" \( -path '*/.git' -o -path '*/.git/*' \) -prune -o -type f -name 'SKILL.md' -print | wc -l | tr -d ' ')"
  [ "$_skill_count" -gt 0 ] || die "在 $ACTIVE_SKILLS_ROOT 下未发现任何 SKILL.md"
}

resolve_skill_name_from_dir() {
  _skill_dir="$1"
  _skill_name="$(sed -n 's/^name:[[:space:]]*//p' "$_skill_dir/SKILL.md" | head -n 1)"
  case "$_skill_name" in
    \"*\") _skill_name="${_skill_name#\"}"; _skill_name="${_skill_name%\"}" ;;
    \'*\') _skill_name="${_skill_name#\'}"; _skill_name="${_skill_name%\'}" ;;
  esac

  [ -n "$_skill_name" ] || die "无法从 $_skill_dir/SKILL.md 解析 skill name"
  case "$_skill_name" in
    */*) die "skill name 不能包含路径分隔符：$_skill_name" ;;
  esac

  printf '%s\n' "$_skill_name"
}

skill_relative_path() {
  _skill_dir="$1"
  case "$_skill_dir" in
    "$ACTIVE_SKILLS_ROOT"/*) printf '%s\n' "${_skill_dir#$ACTIVE_SKILLS_ROOT/}" ;;
    *) printf '%s\n' "$_skill_dir" ;;
  esac
}

normalize_selector() {
  _selector="$(expand_user_path "$1")"
  case "$_selector" in
    "$ACTIVE_SKILLS_ROOT"/*) printf '%s\n' "${_selector#$ACTIVE_SKILLS_ROOT/}" ;;
    ./*) printf '%s\n' "${_selector#./}" ;;
    *) printf '%s\n' "$_selector" ;;
  esac
}

list_skill_dirs() {
  find "$ACTIVE_SKILLS_ROOT" \( -path '*/.git' -o -path '*/.git/*' \) -prune -o -type f -name 'SKILL.md' -print \
    | sort \
    | while IFS= read -r _skill_file; do
        dirname "$_skill_file"
      done
}

selector_matches() {
  _selector="$1"
  _skill_dir="$2"
  _skill_name="$(resolve_skill_name_from_dir "$_skill_dir")"
  _skill_rel="$(skill_relative_path "$_skill_dir")"
  _skill_base="$(basename "$_skill_dir")"

  [ "$_selector" = "$_skill_name" ] \
    || [ "$_selector" = "$_skill_rel" ] \
    || [ "$_selector" = "$_skill_base" ] \
    || [ "$_selector" = "$_skill_dir" ]
}

describe_skill() {
  _skill_dir="$1"
  _skill_name="$(resolve_skill_name_from_dir "$_skill_dir")"
  _skill_rel="$(skill_relative_path "$_skill_dir")"
  say "$_skill_name -> $_skill_rel"
}

resolve_selected_skills() {
  _selector="$1"
  _out_file="$2"
  : > "$_out_file"

  _normalized_selector="all"
  if [ "$_selector" != "all" ]; then
    _normalized_selector="$(normalize_selector "$_selector")"
  fi

  _all_skills_file="$(mktemp)"
  list_skill_dirs > "$_all_skills_file"

  while IFS= read -r _skill_dir; do
    [ -n "$_skill_dir" ] || continue
    if [ "$_selector" = "all" ] || selector_matches "$_normalized_selector" "$_skill_dir"; then
      printf '%s\n' "$_skill_dir" >> "$_out_file"
    fi
  done < "$_all_skills_file"

  rm -f "$_all_skills_file"

  _match_count="$(wc -l < "$_out_file" | tr -d ' ')"
  if [ "$_match_count" -eq 0 ]; then
    if [ "$_selector" = "all" ]; then
      die "未发现可安装的 skills"
    fi
    die "未找到匹配的 skill：$_selector，可先执行 'sh active_skills_install/active_skills_install.sh list' 查看可用项。"
  fi

  if [ "$_selector" != "all" ] && [ "$_match_count" -gt 1 ]; then
    say "匹配到多个 skill，请使用更具体的名称或相对路径："
    while IFS= read -r _skill_dir; do
      describe_skill "$_skill_dir"
    done < "$_out_file"
    die "skill 选择不唯一：$_selector"
  fi
}

install_link() {
  _label="$1"
  _install_dir="$(resolve_target_dir "$2")"
  _skill_dir="$3"
  _skill_name="$(resolve_skill_name_from_dir "$_skill_dir")"
  _target="$_install_dir/$_skill_name"

  mkdir -p "$_install_dir"

  if [ -e "$_target" ] && [ ! -L "$_target" ]; then
    die "$_label 目标已存在且不是软链接：$_target"
  fi

  ln -sfn "$_skill_dir" "$_target"
  say "已安装 $_label Skill: $_target -> $_skill_dir"
}

install_selected_skills() {
  _selector="$1"
  _selected_file="$(mktemp)"
  resolve_selected_skills "$_selector" "$_selected_file"

  while IFS= read -r _skill_dir; do
    [ -n "$_skill_dir" ] || continue
    install_link "Agents" "$AGENTS_INSTALL_DIR" "$_skill_dir"
    install_link "Codex" "$CODEX_INSTALL_DIR" "$_skill_dir"
  done < "$_selected_file"

  rm -f "$_selected_file"
}

print_status_for_skill() {
  _skill_dir="$1"
  _skill_name="$(resolve_skill_name_from_dir "$_skill_dir")"
  _skill_rel="$(skill_relative_path "$_skill_dir")"
  _agents_target="$(resolve_target_dir "$AGENTS_INSTALL_DIR")/$_skill_name"
  _codex_target="$(resolve_target_dir "$CODEX_INSTALL_DIR")/$_skill_name"

  say "skill: $_skill_name"
  say "source: $_skill_dir"
  say "relative path: $_skill_rel"

  if [ -L "$_agents_target" ]; then
    say "agents target: $_agents_target -> $(readlink -f "$_agents_target")"
  else
    say "agents target: $_agents_target (not installed)"
  fi

  if [ -L "$_codex_target" ]; then
    say "codex target: $_codex_target -> $(readlink -f "$_codex_target")"
  else
    say "codex target: $_codex_target (not installed)"
  fi
}

print_status() {
  _selector="${1:-all}"
  _selected_file="$(mktemp)"
  resolve_selected_skills "$_selector" "$_selected_file"

  while IFS= read -r _skill_dir; do
    [ -n "$_skill_dir" ] || continue
    print_status_for_skill "$_skill_dir"
    say ""
  done < "$_selected_file"

  rm -f "$_selected_file"
}

print_list() {
  list_skill_dirs | while IFS= read -r _skill_dir; do
    [ -n "$_skill_dir" ] || continue
    describe_skill "$_skill_dir"
  done
}

print_help() {
  cat <<EOF
active_skills installer

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
EOF
}

main() {
  _cmd="${1:-all}"

  resolve_active_skills_root

  case "$_cmd" in
    help|-h|--help)
      print_help
      ;;
    list)
      print_list
      ;;
    status)
      print_status "${2:-all}"
      ;;
    all|install)
      install_selected_skills "all"
      ;;
    *)
      install_selected_skills "$_cmd"
      ;;
  esac
}

main "$@"