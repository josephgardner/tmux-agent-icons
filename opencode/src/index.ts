import { execFile } from "node:child_process"
import { Plugin } from "@opencode/plugin"

type Event = {
  type: string
  properties?: {
    status?: { type?: string }
    part?: { type?: string; tool?: string; state?: { status?: string } }
  }
}

const pane = process.env.TMUX_PANE

function publish(state?: "working" | "waiting" | "idle") {
  if (!pane) return
  const args = state
    ? ["set-option", "-p", "-t", pane, "@opencode_state", state]
    : ["set-option", "-p", "-u", "-t", pane, "@opencode_state"]
  execFile("tmux", args, () => {})
}

export default Plugin.define({
  id: "tmux-agent-icons",
  setup(ctx) {
    const controller = new AbortController()
    let blocked = false
    let last: string | undefined

    const set = (state: "working" | "waiting" | "idle") => {
      if (state === last) return
      last = state
      publish(state)
    }

    void (async () => {
      for await (const raw of ctx.event.subscribe({ signal: controller.signal })) {
        const event = raw as Event

        if (event.type === "permission.asked") {
          blocked = true
          set("waiting")
        } else if (event.type === "permission.replied") {
          blocked = false
          set("working")
        } else if (event.type === "session.idle" || event.type === "session.error") {
          blocked = false
          set("idle")
        } else if (event.type === "session.status" && !blocked) {
          set(event.properties?.status?.type === "idle" ? "idle" : "working")
        } else if (event.type === "message.part.updated") {
          const part = event.properties?.part
          if (part?.type === "tool" && part.tool === "question") {
            const done = part.state?.status === "completed" || part.state?.status === "error"
            blocked = !done
            set(done ? "working" : "waiting")
          }
        }
      }
    })()

    return () => {
      controller.abort()
      publish()
    }
  },
})
