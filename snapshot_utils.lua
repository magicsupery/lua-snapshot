local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function cleanup_key_value(input)
    local ret = {}
    for k, v in pairs(input) do
        local key = tostring(k)
        local clean_key = key:gmatch("userdata: (%w+)")()
        local val_type
        if v:find("^table") then
            val_type = "table"
        elseif v:find("^func:") then
            val_type = "func"
        elseif v:find("^thread:") then
            val_type = "thread"
        else
            val_type = "userdata"
        end
        local parent = v:match("(%w+) :")
        local _, finish = v:find("(%w+) : ")
        local extra = v:sub(finish + 1, #v)
        local val_key = extra:match("(%w+) :")
        local trim_extra = trim(extra)
        if not val_key then
            val_key = trim_extra
        end
        ret[clean_key] = {
            val_type = val_type,
            parent = parent,
            extra = trim_extra,
            key = val_key,
        }
    end
    return ret
end

local function reduce(input_diff)
    local a_set = {}
    local b_set = {}
    local step = 0
    -- 先收入叶节点
    for self_addr, info in pairs(input_diff) do
        local flag = true
        for _, node in pairs(input_diff) do
            if node.parent == self_addr then
                flag = false
                break
            end
        end
        if flag then
            a_set[self_addr] = info
        end
    end
    step = step + 1
    local MAX_DEPTH = 32
    local dirty
    while step < MAX_DEPTH do
        dirty = false
        -- 遍历叶节点，将parent拉进来
        for self_addr, info in pairs(a_set) do
            local key = info.key
            local parent = info.parent
            local parent_node = input_diff[parent]
            if parent_node then
                if not b_set[parent] then
                    b_set[parent] = parent_node
                end
                parent_node[key] = info
                step = step + 1
                dirty = true
            else
                b_set[self_addr] = info
            end
            a_set[self_addr] = nil
        end
        -- 遍历节点，将祖父节点拉进来
        for self_addr, info in pairs(b_set) do
            local key = info.key
            local parent = info.parent
            local parent_node = input_diff[parent]
            if parent_node then
                if not a_set[parent] then
                    a_set[parent] = parent_node
                end
                parent_node[key] = info
                step = step + 1
                dirty = true
            else
                a_set[self_addr] = info
            end
            b_set[self_addr] = nil
        end
        if not dirty then
            break
        end
    end
    return a_set
end

local unwanted_key = {
    --extra = 1,
    --key = 1,
    parent = 1,
}
local function cleanup_forest(input)
    local cache = {[input] = "."}
    local function _clean(forest)
        if cache[forest] then
            return
        end
        for k, v in pairs(forest) do
            if unwanted_key[k] then
                forest[k] = nil
            else
                if type(v) == "table" then
                    cleanup_forest(v)
                end
             end
         end
	end
    return _clean(input)
end

local print = print
local tconcat = table.concat
local tinsert = table.insert
local srep = string.rep
local type = type
local pairs = pairs
local tostring = tostring
local next = next

local function show(root)
	local cache = {  [root] = "." }
	local function _dump(t,space,name)
		local temp = {}
		for k,v in pairs(t) do
			local key = tostring(k)
			if cache[v] then
				tinsert(temp,"+" .. key .. " {" .. cache[v].."}")
			elseif type(v) == "table" then
				local new_key = name .. "." .. key
				cache[v] = new_key
				tinsert(temp,"+" .. key .. _dump(v,space .. (next(t,k) and "|" or " " ).. srep(" ",#key),new_key))
			else
				tinsert(temp,"+" .. key .. " [" .. tostring(v).."]")
			end
		end
		return tconcat(temp,"\n"..space)
	end
	print(_dump(root, "",""))
end

local M = {}

function M.show_diff(s1, s2)
	local input_diff = {}
	for k,v in pairs(s2) do
		if not s1[k] then
			input_diff[k] = v
		end
	end
	print("===================INPUTDIFF SHOW==========================")
	show(input_diff)
	
	local clean_diff = cleanup_key_value(input_diff)
    local forest = reduce(clean_diff)
    cleanup_forest(forest)
	print("===================FOREST SHOW==========================")
	show(forest)
	
	
end


return M
