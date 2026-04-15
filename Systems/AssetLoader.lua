local HttpService = game:GetService("HttpService")
local FileManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/amzfdrsigusk-ops/Legacy/main/Systems/FileManager.lua"))()

local function AssetLoader()
    local VersionPath = "Legacy/.version"

    local function BuildAssetLoader()
        local AssetLoader = {
            Cache = {},
            Roots = {
                "Legacy/Assets/"
            }
        }

        local function ResolvePath(Path)
            for _, Root in ipairs(AssetLoader.Roots) do
                local FullPath = Root .. Path
                if FileManager:IsFile(FullPath) then
                    return FullPath
                end
            end
        end

        local function ConvertAsset(FullPath)
            if AssetLoader.Cache[FullPath] then
                return AssetLoader.Cache[FullPath]
            end

            local AssetId
            for Index = 1, 3 do
                local Success, Result = pcall(function()
                    return (getcustomasset and getcustomasset(FullPath)) or getsynasset(FullPath)
                end)
                if Success and Result then
                    AssetId = Result
                    break
                end
                task.wait()
            end

            if not AssetId then
                AssetId = (getcustomasset and getcustomasset(FullPath)) or getsynasset(FullPath)
            end

            AssetLoader.Cache[FullPath] = AssetId
            return AssetId
        end

        function AssetLoader:GetImage(Path)
            local FullPath = ResolvePath(Path)
            return FullPath and ConvertAsset(FullPath)
        end

        function AssetLoader:GetSound(Path)
            local FullPath = ResolvePath(Path)
            return FullPath and ConvertAsset(FullPath)
        end

        function AssetLoader:GetFont(FontName)
            local TtfPath = "Legacy/Assets/Fonts/" .. FontName
            if not TtfPath:lower():match("%.ttf$") then
                TtfPath = TtfPath .. ".ttf"
            end

            if not FileManager:IsFile(TtfPath) then
                return Font.new("rbxasset://fonts/families/SourceSansPro.json")
            end

            if self.Cache[TtfPath] then
                return self.Cache[TtfPath]
            end

            local AssetId = (getcustomasset and getcustomasset(TtfPath)) or (getsynasset and getsynasset(TtfPath))
            if not AssetId then
                return Font.new("rbxasset://fonts/families/SourceSansPro.json")
            end

            local JsonPath = "Legacy/Assets/Fonts/" .. FontName .. ".json"

            if not FileManager:IsFile(JsonPath) then
                local FontData = {
                    name = FontName,
                    faces = {
                        {
                            name = "Regular",
                            weight = 400,
                            style = "normal",
                            assetId = AssetId
                        }
                    }
                }
                FileManager:WriteFile(JsonPath, HttpService:JSONEncode(FontData))
            end

            local FamilyAssetId = (getcustomasset and getcustomasset(JsonPath)) or (getsynasset and getsynasset(JsonPath))
            if not FamilyAssetId then
                return Font.new("rbxasset://fonts/families/SourceSansPro.json")
            end

            local NewFont = Font.new(FamilyAssetId)
            self.Cache[TtfPath] = NewFont
            return NewFont
        end

        function AssetLoader:LoadModel(Path, Parent)
            local FullPath = ResolvePath(Path)
            if not FullPath then
                return
            end

            local Objects = game:GetObjects(ConvertAsset(FullPath))
            if Objects and Objects[1] then
                Objects[1].Parent = Parent or workspace
                return Objects[1]
            end
        end

        return AssetLoader
    end

    local function HttpGet(Url)
        local Success, Response = pcall(function()
            return request({
                Url = Url,
                Method = "GET",
                Headers = {
                    ["User-Agent"] = "Roblox",
                    ["Accept"] = "application/vnd.github+json"
                }
            })
        end)
        if Success and Response and Response.Body and #Response.Body > 0 then
            return Response.Body
        end
        return nil
    end

    local function SafeJSONDecode(Body)
        if not Body or #Body == 0 then
            return nil
        end
        local Success, Result = pcall(function()
            return HttpService:JSONDecode(Body)
        end)
        if Success and type(Result) == "table" then
            return Result
        end
        return nil
    end

    local function GetRemoteSHA()
        local ApiUrl = "https://api.github.com/repos/amzfdrsigusk-ops/Legacy/commits/main"
        local Body = HttpGet(ApiUrl)
        local Data = SafeJSONDecode(Body)

        if Data and Data.sha then
            return Data.sha
        end

        local RawUrl = "https://api.github.com/repos/amzfdrsigusk-ops/Legacy/git/refs/heads/main"
        Body = HttpGet(RawUrl)
        Data = SafeJSONDecode(Body)

        if Data and Data.object and Data.object.sha then
            return Data.object.sha
        end

        return nil
    end

    local function GetLocalSHA()
        if FileManager:IsFile(VersionPath) then
            return FileManager:ReadFile(VersionPath)
        end
    end

    local RemoteSHA = GetRemoteSHA()
    local LocalSHA = GetLocalSHA()

    if LocalSHA and RemoteSHA and LocalSHA == RemoteSHA then
        return BuildAssetLoader()
    end

    local function HttpGetWithRetry(Url, MaxRetries)
        MaxRetries = MaxRetries or 3
        for Attempt = 1, MaxRetries do
            local Success, Response = pcall(function()
                return request({
                    Url = Url,
                    Method = "GET",
                    Headers = {
                        ["User-Agent"] = "Roblox",
                        ["Accept"] = "application/vnd.github+json"
                    }
                })
            end)
            if Success and Response and Response.Body and #Response.Body > 0 then
                local Data = SafeJSONDecode(Response.Body)
                if Data and Data.message and Data.message:lower():match("rate limit") then
                    task.wait(2 * Attempt)
                else
                    return Response.Body
                end
            else
                task.wait(1)
            end
        end
        return nil
    end

    local function WalkFolder(RepoPath, LocalPath)
        local Url = "https://api.github.com/repos/amzfdrsigusk-ops/Legacy/contents/" .. RepoPath .. "?ref=main"
        local Body = HttpGetWithRetry(Url)
        local Items = SafeJSONDecode(Body)

        if not Items or type(Items) ~= "table" then
            return
        end

        if Items.message then
            return
        end

        for _, Item in ipairs(Items) do
            local OutputPath = LocalPath .. "/" .. Item.name

            if Item.type == "dir" then
                FileManager:CreateFolder(OutputPath)
                WalkFolder(Item.path, OutputPath)
            elseif Item.type == "file" then
                local FileBody = HttpGetWithRetry(Item.download_url)
                if FileBody then
                    FileManager:WriteFile(OutputPath, FileBody)
                end
            end
        end
    end

    FileManager:CreateFolder("Legacy/Assets")
    WalkFolder("Assets", "Legacy/Assets")

    local function CreateFontJson(TtfPath)
        TtfPath = FileManager:Normalize(TtfPath)

        if not TtfPath:lower():match("%.ttf$") then
            return
        end

        local Directory, FileName = TtfPath:match("(.+)/([^/]+)$")
        if not Directory or not FileName then
            return
        end

        local BaseName = FileName:gsub("%.ttf$", "")
        local JsonPath = Directory .. "/" .. BaseName .. ".json"

        if FileManager:IsFile(JsonPath) then
            return
        end

        local AssetId = (getcustomasset and getcustomasset(TtfPath)) or (getsynasset and getsynasset(TtfPath))
        if not AssetId then
            return
        end

        local FontData = {
            name = BaseName,
            faces = {
                {
                    name = "Regular",
                    assetId = AssetId,
                    weight = 400,
                    style = "normal"
                }
            }
        }

        FileManager:WriteFile(JsonPath, HttpService:JSONEncode(FontData))
    end

    local function ScanFonts(Root)
        Root = FileManager:Normalize(Root)

        if not FileManager:IsFolder(Root) then
            return
        end

        for _, Item in ipairs(FileManager:ListFiles(Root)) do
            Item = FileManager:Normalize(Item)

            if Item:lower():match("%.ttf$") then
                CreateFontJson(Item)
            elseif not Item:match("%.%w+$") then
                ScanFonts(Item)
            end
        end
    end

    ScanFonts("Legacy/Assets/Fonts")

    local PreloadList = {}

    if FileManager:IsFolder("Legacy/Assets") then
        for _, File in ipairs(FileManager:ListFiles("Legacy/Assets")) do
            if File:match("%.(png|jpg|jpeg|wav|mp3|ogg|json|rbxm|rbxmx|ttf|otf)$") then
                table.insert(PreloadList, File)
            end
        end
    end

    local Loader = BuildAssetLoader()

    for _, File in ipairs(PreloadList) do
        Loader.Cache[File] = (getcustomasset and getcustomasset(File)) or (getsynasset and getsynasset(File))
    end

    if RemoteSHA then
        FileManager:WriteFile(VersionPath, RemoteSHA)
    end

    return Loader
end

return AssetLoader()