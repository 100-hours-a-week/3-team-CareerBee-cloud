function trim(tag, timestamp, record)
    local raw = record["log"]
    local trimmed = string.match(raw, "startup%-script: (.*)")
    if trimmed then
        record["log"] = trimmed
    end
    return 1, timestamp, record
end