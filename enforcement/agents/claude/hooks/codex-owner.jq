# The supported response_item schema is runtime-derived, not a universal parser.
# Last session_meta overrides inherited root records in child transcripts.
([.[] | select(.type == "session_meta") | .payload] | last) as $meta
| if $meta == null then error("missing session provenance")
  elif ($meta.source | type) == "object" or $meta.thread_source == "subagent" or $meta.thread_source == "guardian_review" or $meta.parent_thread_id != null then null
  elif $meta.source != "cli" or $meta.thread_source != "user" then error("unsupported session provenance")
  else
    [.[] | select(.type == "response_item" and .payload.type == "message" and .payload.role == "user")] as $users
    # User messages none of which carry the known owner marker: a format we do not read.
    | if $users != [] and all($users[]; (.payload.internal_chat_message_metadata_passthrough.content_item_kinds | type) != "array")
      then error("unsupported owner message format") else . end
    | [$users[] | .payload
      | .internal_chat_message_metadata_passthrough as $m
      | select(($m.content_item_kinds | type) == "array")
      | . as $p
      | [range(0; .content | length) as $i | select($m.content_item_kinds[$i] == "user.text")
          | $p.content[$i] | select(.type == "input_text" and (.text | type) == "string") | .text] as $parts
      | select($parts | length > 0)
      | {id:(.id // $m.turn_id // ($m.create_time | if . == null then null else tostring end)), text:($parts | join("\n"))}]
    | last
  end
