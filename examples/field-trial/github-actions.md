# GitHub Actions 工作流维护备忘录

## Workflow 触发

“Workflow triggers are events that cause a workflow to run.”（[GitHub Docs](https://docs.github.com/en/actions/concepts/workflows-and-actions/workflows)）应通过 `on` 明确事件、活动类型及分支、标签或路径过滤条件，避免宽泛触发。多个事件按“或”处理：“If you specify multiple events, only one of those events needs to occur to trigger your workflow.”（[GitHub Docs](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax)）同时设置 `branches` 与 `paths` 时，则两者必须同时满足。对 `pull_request_target` 应格外谨慎，不要在高权限上下文执行来自不可信分支的代码。

## Concurrency

默认允许多个运行并行。部署、发布等具有共享状态的流程应设置稳定且范围明确的 `concurrency.group`；分支级任务通常可组合 `${{ github.workflow }}` 与 `${{ github.ref }}`。“Concurrency ensures that only a single job or workflow using the same concurrency group will run at a time.”（[GitHub Docs](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/control-deployments)）`cancel-in-progress: true` 适合取消已过时的检查，但可能中断部署，不应机械启用；组名相同还可能跨工作流互相影响。

## Secrets

“GitHub Actions can only read a secret if you explicitly include the secret in a workflow.”（[GitHub Docs](https://docs.github.com/en/actions/concepts/security/secrets)）仅通过 `secrets` 上下文把凭据传给确有需要的步骤，并优先使用环境级 secret、审批规则及 OIDC，避免长期云密钥。注意：“Secrets are not automatically passed to reusable workflows.”（[GitHub Docs](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets)）Fork PR 与 Dependabot 触发也有额外限制。`GITHUB_TOKEN` 应用 `permissions` 显式收窄到最小权限，且不得把日志脱敏视为绝对保障。