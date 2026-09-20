import type { Plugin } from "@opencode-ai/plugin"
import { execFileSync } from "node:child_process"

const AGENT = "opencode"
const OPTION = `@${AGENT}_state`

let last: string | undefined
let blocked = false

function publish(state: "working" | "waiting" | "idle" | "end") {
  if (state === last) return
  last = state

  const pane = process.env.TMUX_PANE
  if (!pane) return

  const args =
    state === "end"
      ? ["set", "-pu", "-t", pane, OPTION]
      : ["set", "-p", "-t", pane, OPTION, state]

  try {
    execFileSync("tmux", args, { stdio: "ignore" })
  } catch {
    // tmux unavailable or pane gone; nothing to publish.
  }
}

// A blocked turn (permission prompt or question tool) stays ✋ even if the
// session keeps reporting itself busy while it waits for the user.
function setState(state: "working" | "waiting" | "idle" | "end") {
  if (state === "working") {
    if (blocked) return
  } else if (state === "waiting") {
    blocked = true
  } else {
    blocked = false
  }
  publish(state)
}

function resume() {
  blocked = false
  publish("working")
}

type BusEvent = {
  type: string
  properties?: {
    status?: { type?: string }
    part?: { type?: string; tool?: string; state?: { status?: string } }
  }
}

export const TmuxAgentState: Plugin = async () => {
  return {
    event: async ({ event }) => {
      const e = event as BusEvent
      switch (e.type) {
        case "session.status":
          setState(e.properties?.status?.type === "idle" ? "idle" : "working")
          break
        case "session.idle":
        case "session.error":
          setState("idle")
          break
        case "message.part.updated": {
          const part = e.properties?.part
          if (part?.type === "tool" && part.tool === "question") {
            if (part.state?.status === "completed" || part.state?.status === "error") resume()
            else setState("waiting")
          }
          break
        }
        case "permission.asked":
        case "permission.updated":
          setState("waiting")
          break
        case "permission.replied":
          resume()
          break
      }
    },
    dispose: async () => {
      setState("end")
    },
  }
}