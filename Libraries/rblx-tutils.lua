local tutils = {}

function tutils.checkListConsistency(t : Table)
	local containsNumberKey = false
	local containsStringKey = false
	local numberConsistency = true

	local index = 1
	for x, _ in pairs(t) do
		if type(x) == 'string' then
			containsStringKey = true
		elseif type(x) == 'number' then
			if index ~= x then
				numberConsistency = false
			end
			containsNumberKey = true
		else
			return false
		end

		if containsStringKey and containsNumberKey then
			return false
		end

		index = index + 1
	end

	if containsNumberKey then
		return numberConsistency
	end

	return true
end

function tutils.deepCopy(A : Table, seen : Table)
	if type(A) ~= 'table' then
		return A
	end

	if seen and seen[A] then
		return seen[A]
	end

	local alreadySeen  = seen or {}
	local newTable = setmetatable({}, getmetatable(A))
	alreadySeen[A] = newTable
	for key, value in pairs(A) do
		newTable[tutils.deepCopy(key, alreadySeen)] = tutils.deepCopy(value, alreadySeen)
	end
	return newTable
end

function tutils.deepEqual(A : Table, B : Table, ignoreMetatables : Boolean)
	if A == B then
		return true
	end
	local AType = type(A)
	local BType = type(B)
	if AType ~= BType then
		return false
	end
	if AType ~= "table" then
		return false
	end

	if not ignoreMetatables then
		local mt1 = getmetatable(A)
		if mt1 and mt1.__eq then
			--compare using built in method
			return A == B
		end
	end

	local keySet = {}

	for key1, value1 in pairs(A) do
		local value2 = B[key1]
		if value2 == nil or not deepEqual(value1, value2, ignoreMetatables) then
			return false
		end
		keySet[key1] = true
	end

	for key2, _ in pairs(B) do
		if not keySet[key2] then
			return false
		end
	end
	return true
end

function tutils.equalKey(A : Table, B : Table, key : Any)
	if A and B and key and key ~= "" and A[key] and B[key] and A[key] == B[key] then
		return true
	end
	return false
end

function tutils.fieldCount(t : Table)
	local fieldCount = 0
	for _ in pairs(t) do
		fieldCount = fieldCount + 1
	end
	return fieldCount
end

local function membershipTable(list : Table)
	local result = {}
	for i = 1, #list do
		result[list[i]] = true
	end
	return result
end

local function listOfKeys(t : Table)
	local result = {}
	for key,_ in pairs(t) do
		table.insert(result, key)
	end
	return result
end

function tutils.listDifferences(A : Table, B : Table)
	return listOfKeys(tutils.tableDifference(membershipTable(A), membershipTable(B)))
end

tutils.print = function()
	local function makeKeyString(key)
		if type(key) == "string" then
			return string.format("%s", key)
		else
			return string.format("[%s]", tostring(key))
		end
	end

	local function makeValueString(value)
		local valueType = type(value)
		if valueType == "string" then
			return string.format("%q", value)
		elseif valueType == "function" or valueType == "table" then
			return string.format("<%s>", tostring(value))
		else
			return string.format("%s", tostring(value))
		end
	end

	local function printKeypair(key, value, indentStr, comment)
		local keyString = makeKeyString(key)
		local valueString = makeValueString(value)

		local commentStr = comment and string.format(" -- %s", comment) or ""
		print(string.format("%s%s = %s,%s", indentStr, keyString, valueString, commentStr))
	end

	--[[
		For debugging. Prints the table on multiple lines to overcome log-line length
		limitations which are otherwise necessary for performance. Use sparingly.
	]]
	return function(t, indent)
		indent = indent or '  '

		if type(t) ~= "table" then
			error("tutils.Print must be passed a table", 2)
		end

		-- For cycle detection
		local printedTables = {}

		local function recurse(subTable, tableKey, level)
			-- Prevent cycles by keeping track of what tables we have printed
			printedTables[subTable] = true

			local indentStr = string.rep(indent, level)
			local valueIndentStr = string.rep(indent, level + 1)

			if tableKey then
				print(string.format("%s%s = %s {", indentStr, makeKeyString(tableKey), makeValueString(subTable)))
			else
				print(string.format("%s%s {", indentStr, makeValueString(subTable)))
			end

			for key, value in pairs(subTable) do
				if type(value) == "table" then
					if printedTables[value] then
						printKeypair(key, value, valueIndentStr, "Possible cycle")
					else
						recurse(value, key, level + 1)
					end
				else
					printKeypair(key, value, valueIndentStr)
				end
			end

			print(string.format("%s}%s", indentStr, (level > 0 and "," or "")))
		end

		recurse(t, nil, 0)
	end
end

function tutils.shallowEqual(A : Table, B : Table, ignore : Table)
	if not A or not B then
		return false
	elseif A == B then
		return true
	end
	if not ignore then
		ignore = {}
	end

	for key, value in pairs(A) do
		if B[key] ~= value and not ignore[key] then
			return false
		end
	end
	for key, value in pairs(B) do
		if A[key] ~= value and not ignore[key] then
			return false
		end
	end

	return true
end

function tutils.tableDifference(A : Table, B : Table)
	local new = {}

	for keyA, valueA in pairs(A) do
		if B[keyA] ~= A[keyA] then
			new[keyA] = valueA
		end
	end

	for keyB, valueB in pairs(B) do
		if B[keyB] ~= A[keyB] then
			new[keyB] = valueB
		end
	end

	return new
end

function tutils.recursiveToString(t : Table, indent : String | Nil)
	indent = indent or ''

	if type(t) == 'table' then
		local result = ""
		if not tutils.checkListConsistency(t) then
			result = result .. "-- WARNING: this table fails the list consistency test\n"
		end
		result = result .. "{\n"
		for k,v in pairs(t) do
			if type(k) == 'string' then
				result = result
					.. "  "
					.. indent
					.. tostring(k)
					.. " = "
					.. recursiveToString(v, "  "..indent)
					..";\n"
			end
			if type(k) == 'number' then
				result = result .. "  " .. indent .. recursiveToString(v, "  "..indent)..",\n"
			end
		end
		result = result .. indent .. "}"
		return result
	else
		return tostring(t)
	end
end

function tutils.deepMerge(A : Table, B : Table, seen : Table)
	if type(A) ~= 'table' then
		return A
	end

	if seen and seen[A] then
		return seen[A]
	end

	local new = tutils.deepCopy(B)
	for key, value in pairs(A) do
		if new[key] == nil then
			new[key] = value
			if typeof(value) == "table" then
				new[key] = tutils.deepMerge(value, new, seen)
			end
		end
	end
	return new
end

local matchFunctions = {
    value = function(value : Any, check : Any, find : Boolean)
        return value == check or (find and string.find(tostring(value), check))
    end,
    key = function(key : Any, check : Any, find : Boolean)
        return key == check or (find and string.find(tostring(key), check))
    end
}
matchFunctions.index = matchFunctions.key

local function search_for(tbl : Table, val : String, method : String, find : Boolean, multiple : Boolean, metatables : Boolean, searched : Table, successful : Table, seen : Table)
    local res
    for i, v in pairs(tbl) do
        if matchFunctions[method](v, val, find) then
            res = true
			print(i, v)
            table.insert(searched, i)
            if not multiple then
                break
            end
        end
        if typeof(v) == "table" and table.find(seen) == nil then
            table.insert(seen, v)
            if metatables then
				if typeof(getrawmetatable(v)) == "table" then
					table.insert(seen, getrawmetatable(v))
					table.insert(searched, {__ismeta = true, key = i})
					res, sresult, successful2 = search_for(getrawmetatable(v), val, method, find, multiple, metatables, table.clone(searched), successful, seen)
					if res then
						successful[Indentifier:getID()] = sresult
						successful = tutils.deepMerge(successful, successful2)
						if not multiple then
							break
						end
					end
					local found = table.find(searched, i)
					if found then
						table.remove(searched, found)
					end
				end
			else
				table.insert(searched, i)
				res, sresult, successful2 = search_for(v, val, method, find, multiple, metatables, table.clone(searched), successful, seen)
				if res then
					successful[Indentifier:getID()] = sresult
					successful = tutils.deepMerge(successful, successful2)
					if not multiple then
						break
					end
				end
				local found = table.find(searched, i)
				if found then
					table.remove(searched, found)
				end
			end
        end
    end
	return res, searched, successful
end

function tutils.search(tbl : Table, val : Any, method : String, find : Boolean, multi : Boolean, onlyMT : Boolean)
    method = typeof(method) == "string" and method or "value"
	local suc, _, successful = search_for(tbl, val, method, find, multi, onlyMT, {}, {}, {})
    local results = {}
    for i, v in pairs(successful) do
        table.insert(results, v)
    end
    if not multi then
        return suc, results[1]
    end
	return suc, results or {[1] = {}}
end

function tutils.accessTable(tbl : Table, list : Table, mode : String, object : Any)
    assert(#list > 0, "cannot pass empty table")
    t.strict(t.union(function() return mode ~= "cwrite" end, t.callback(object)))
    local index = list[1]
    table.remove(list, 1)
    if #list > 0 then
        if typeof(index) == "table" then
            if index.__ismeta then
                return tutils.accessTable(getrawmetatable(tbl, index), list, mode, object)
            end
        end
        return tutils.accessTable(rawget(tbl, index), list, mode, object)
    else
        if mode == "write" then
            local readonly = isreadonly(tbl)
            makewriteable(tbl)
            t[index] = object
            rawset(tbl, index, object)
			if readonly then
           		makereadonly(tbl)
			end
            return t[index] == object
        elseif mode == "cwrite" then
            return object(t)
        elseif mode == "read" then
            return t[index]
        elseif mode == "rread" then
            return rawget(tbl, index)
        end
    end
end

-- access_table(table, '[1]["strin"][0]', "write" or "cwrite" or "read" or "rread", "value_if_mode_is_write_")

return tutils