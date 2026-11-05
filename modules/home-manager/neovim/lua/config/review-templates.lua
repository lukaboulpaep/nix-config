-- Compose one audience with one action. Add entries to either list to extend
-- the export picker. Text is plain Markdown; no Git or hosting actions run.
-- Document placeholders: {audience}, {action}, {context}, {comments}, {count}.
-- Comment placeholders: {index}, {type}, {location}, {side}, {text}, {file},
-- {revision} (snapshot/range), {selection} (quoted selected code).
return {
  default_audience = "agent",
  default_action = "feedback",
  document = "{audience}\n\n{context}\n\n{action}\n\n{comments}\n",
  comment = "### {index}. {type} — {location} ({side} side){revision}{selection}\n\n{text}",
  audiences = {
    { id = "agent", label = "Agent", text = "# Feedback on your latest changes" },
    {
      id = "review",
      label = "Pull / merge request",
      text = "# Pull / merge request feedback\n\nTarget PR/MR: <add URL or number>",
      -- Same action, different delivery: these instructions are copied for the
      -- agent. Neovim itself does not publish anything to the hosting service.
      actions = {
        feedback =
        "Post the comments below on the target PR/MR. Use inline comments at the specified file, revision, side and line range where supported; post whole-file notes as file-level comments or clearly labelled review comments. Preserve the wording. If the target PR/MR is missing or ambiguous, ask for its URL before posting. Do not modify the code.",
      },
    },
  },
  actions = {
    { id = "feedback", label = "Feedback only",             text = "Please address the comments below." },
    { id = "verify",   label = "Check comments addressed",  text = "Check the current code against each comment below. For each one, report whether it is addressed, partially addressed, or still open, with a short explanation and the relevant file/line or commit. Do not make changes; identify what remains to be done." },
    { id = "working",  label = "Update working changes",    text = "Please apply the requested changes to the working tree and leave them uncommitted." },
    { id = "amend",    label = "Amend the reviewed commit", text = "Please incorporate this feedback into the reviewed commit by amending it, preserving its scope and message unless the feedback requires otherwise. If the review spans several commits, identify the intended target before rewriting history. Do not push the rewritten history." },
    { id = "fixup",    label = "Create fixup commits",      text = "Please create fixup commits targeting the reviewed commits that each correction belongs to. Keep unrelated corrections separate and report the target commit for each fixup. Leave the fixups ready for autosquash; do not rebase or push yet." },
  },
}
