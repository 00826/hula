--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local AvatarEditorService = game:GetService("AvatarEditorService")
local GroupService = game:GetService("GroupService")
local LocalizationService = game:GetService("LocalizationService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")

--- ### patronage.luau
---
--- player patronage: \
--- marketplace products \
--- prompt favorite \
--- group membership \
--- policyinfo \
--- region code
local patronage = {}

--- creates a minimal buyable product
function patronage.createproduct(type: Enum.InfoType|Enum.MembershipType)
	return {
		key = 0 :: (string|number);
		value = nil :: any;

		type = type;
		price = 0;
		currency = Enum.CurrencyType.Default;

		--- & {[string]: any}
		[(nil::any)::string] = nil::any;
	}
end

--- returns `pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, p.key, p.type)` \
--- returns `false, string` if `p.type.EnumType == Enum.MembershipType` \
--- [*2nd return value is a union type of all possible key-value pairs and does not reflect what the return type might actually be*](https://https://create.roblox.com/docs/reference/engine/classes/MarketplaceService#GetProductInfoAsync)
function patronage.productinfo(p: typeof(patronage.createproduct(...))): (boolean, (
	--- base product information
	{
		--- name shown on the asset's page
		Name: string;
		--- description shown on the asset's page; can be nil if blank
		Description: string?;
		--- cost of purchasing the asset using Robux
		PriceInRobux: number;
		--- product id if `p.type == Enum.InfoType.Product`
		ProductId: number;
		--- string describing what the product is. not to be confused with `Enum.MarketplaceProductType`
		ProductType: string;
		--- ISO 8601 timestamp of when the asset was created
		Created: string;
		--- ISO 8601 timestamp of when the asset was last updated by its creator
		Updated: string;
		--- whether the item is marked as 13+ in catalog
		ContentRatingTypeId: number;
		--- minimum subscription level necessary to purchase the item
		MinimumMembershipLevel: number;
		--- whether the asset can be taken for free
		IsPublicDomain: boolean;
		--- id of the product or asset
		TargetId: number;
	}
	--- creator information
	& {
		Creator: {
			--- either `"User"` or `"Group"`
			CreatorType: "User" | "Group";
			--- id of the creator user or group
			CreatorTargetId: number;
			--- whether the creator has a verified badge
			HasVerifiedBadge: boolean;
			--- name/username of the creator
			Name: string;
			--- use `CreatorTargetId` instead
			Id: string;
		};
	}
	--- asset information
	& {
		--- asset id if `p.type == Enum.InfoType.Asset`
		AssetId: number;
		--- type of asset. See `Enum.AssetType` for the asset type id numbers
		AssetTypeId: number;
		--- asset id of the product's icon, or `0` if there isn't one
		IconImageAssetId: number;
		--- whether the asset is purchasable
		IsForSale: boolean;
		--- whether the asset is a Roblox Limited that is no longer (if ever) sold
		IsLimited: boolean;
		--- whether the asset is a unique Roblox Limited ("Limited U") item that only has a fixed number sold
		IsLimitedUnique: boolean;
		--- whether the asset is marked as "new" in the catalog
		IsNew: boolean;
		--- remaining number of times a limited unique item may be sold
		Remaining: number;
		--- number of times the asset has been sold
		Sales: number;
	}
	--- collectibles information
	& {
		--- unique item id of the collectible
		CollectibleItemId: string;
		--- unique product id of the collectible
		CollectibleProductId: string;
		--- table of information describing the collectible
		CollectiblesItemDetails: {
			--- unique item instance id of the lowest available resale for the collectible
			CollectibleLowestAvailableResaleItemInstanceId: string;
			--- unique product id of the lowest available resale for the collectible
			CollectibleLowestAvailableResaleProductId: string;
			--- lowest resale price for the collectible in Robux
			CollectibleLowestResalePrice: number;
			--- whether the collectible is available for sale (not resale)
			IsForSale: boolean;
			--- whether or not the collectible is limited
			IsLimited: boolean;
			--- total quantity of the collectible available for purchase (not resale)
			TotalQuantity: number;
		}
	}
	--- sale location settings
	& {
		--- whether the asset is purchasable in the current game
		CanBeSoldInThisGame: boolean;
		--- table of information describing where the item can be sold
		SaleLocation: {
			--- type of sale location setting. See `Enum.ProductLocationRestriction` for the sale location setting id numbers
			SaleLocationType: number;
			--- array of universes in which the item can be sold (not currently implemented)
			UniverseIds: {number};
		}
	}
)?)
	if p.type.EnumType == Enum.MembershipType then
		return false, "cannot get product info for enumtype 'Enum.MembershipType'"::any
	else
		return pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, p.key, p.type)
	end
end

--- returns `pcall`-wrapped marketplaceservice method for reading product ownership of `p` \
--- `p.type == Enum.InfoType.Product` will always return `true, false` \
--- `p.type == Enum.MembershipType.Premium` will return `true, player.MembershipType == type`
function patronage.productownership(p: typeof(patronage.createproduct(...)), player: Player): (boolean, boolean | { IsSubscribed: boolean; IsRenewing: boolean; })
	local type = p.type
	local key = p.key

	if type == Enum.InfoType.Asset then
		return pcall(MarketplaceService.PlayerOwnsAssetAsync, MarketplaceService, player, key)
	elseif type == Enum.InfoType.Bundle then
		return pcall(MarketplaceService.PlayerOwnsBundleAsync, MarketplaceService, player, key)
	elseif type == Enum.InfoType.GamePass then
		return pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, key)
	elseif type == Enum.InfoType.Product then
		return true, false --- can never own a devproduct
	elseif type == Enum.InfoType.Subscription then
		return pcall(MarketplaceService.GetUserSubscriptionStatusAsync, MarketplaceService, player)
	elseif type == Enum.MembershipType.Premium then
		return true, player.MembershipType == type::Enum.MembershipType
	else
		error(string.format("unaccounted minproduct infotype (key: %s, infotype: %s)", tostring(key), type.Name))
	end
end

--- returns `pcall`-wrapped marketplaceservice method for purchasing product `p`
function patronage.productpromptpurchase(p: typeof(patronage.createproduct(...)), player: Player): (boolean, any)
	local type = p.type
	local key = p.key

	if type == Enum.InfoType.Asset then
		return pcall(MarketplaceService.PromptPurchase, MarketplaceService, player, key)
	elseif type == Enum.InfoType.Bundle then
		return pcall(MarketplaceService.PromptBundlePurchase, MarketplaceService, player, key)
	elseif type == Enum.InfoType.GamePass then
		return pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, key)
	elseif type == Enum.InfoType.Product then
		return pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, key)
	elseif type == Enum.InfoType.Subscription then
		return pcall(MarketplaceService.PromptSubscriptionPurchase, MarketplaceService, player, key)
	elseif type == Enum.MembershipType.Premium then
		return pcall(MarketplaceService.PromptPremiumPurchase, player)
	else
		error(string.format("unaccounted minproduct type (key: %s, type: %s)", tostring(key), type.Name))
	end
end

--- connects functions to their marketplaceservice purchase-finished events \
--- `t.product` is written to `MarketplaceService.ProcessReceipt` \
--- `[!]` ownership should be verified with `patronage.productownership()`
function patronage.productpurchases(t: {
	--- `MarketplaceService.PromptPurchaseFinished`
	asset: (player: Player, id: number, purchased: boolean) -> ();
	--- `MarketplaceService.PromptBundlePurchaseFinished`
	bundle: (player: Player, id: number, purchased: boolean) -> ();
	--- `MarketplaceService.PromptGamePassPurchaseFinished`
	gamepass: (player: Player, id: number, purchased: boolean) -> ();
	--- `MarketplaceService.ProcessReceipt`
	product: ({
		PurchaseId: string;
		PlayerId: number;
		ProductId: number;
		PlaceIdWherePurchased: number;
		CurrencySpent: number;
		--- always `Enum.CurrencyType.Robux`
		CurrencyType: Enum.CurrencyType;
	}) -> (Enum.ProductPurchaseDecision);
	--- `Players.UserSubscriptionStatusChanged`
	subscription: (player: Player, id: string) -> ();
	--- `Players.PlayerMembershipChanged`
	premium: (player: Player) -> ();
})
	assert(RunService:IsServer(), "patronage.productpurchases() can only be called on server")

	MarketplaceService.ProcessReceipt = t.product

	return {
		asset = MarketplaceService.PromptPurchaseFinished:Connect(t.asset);
		bundle = MarketplaceService.PromptBundlePurchaseFinished:Connect(t.bundle);
		gamepass = MarketplaceService.PromptGamePassPurchaseFinished:Connect(t.gamepass);
		receipt = MarketplaceService.ProcessReceipt;
		subscription = Players.UserSubscriptionStatusChanged:Connect(t.subscription);
		premium = Players.PlayerMembershipChanged:Connect(t.premium);
	}
end

--- returns `pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, assetid, avataritemtype, shouldfavorite)`
function patronage.promptsetfavorite(assetid: number, avataritemtype: Enum.AvatarItemType, shouldfavorite: boolean)
	return pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, assetid, avataritemtype, shouldfavorite)
end

--- returns `AvatarEditorService.PromptSetFavoriteCompleted`
function patronage.promptsetfavoritecompleted()
	return AvatarEditorService.PromptSetFavoriteCompleted
end

--- returns result of `pcall`-wrapped group membership methods for `player` 
function patronage.groupmembership(player: Player, groupid: number)
	local a, isingroup = pcall(player.IsInGroupAsync, player, groupid)
	if not a then
		warn(isingroup)
		isingroup = false
	end

	local b, rank = pcall(player.GetRankInGroupAsync, player, groupid)
	if not b then
		warn(rank)
		rank = 0
	end

	local c, role = pcall(player.GetRoleInGroupAsync, player, groupid)
	if not c then
		warn(role)
		role = ""
	end

	return {
		--- `player.IsInGroupAsync(player, groupid)`
		isingroup = isingroup;
		--- `player.GetRankInGroupAsync(player, groupid)`
		rank = rank;
		--- `player.GetRoleInGroupAsync(player, groupid)`
		role = role;
	}
end

--- returns `pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)`
function patronage.groupsof(player: Player): (boolean, {{
	Name: string;
	Id: number;
	EmblemUrl: string;
	EmblemId: string;
	Rank: number;
	Role: string;
	IsPrimary: boolean;
	IsInClan: false;
}})
	return pcall(GroupService.GetGroupsAsync, GroupService, player.UserId)
end

--- returns `pcall(GroupService.GetGroupInfoAsync, GroupService, groupid)`
function patronage.groupinfo(groupid: number): (boolean, {
	Description: string;
	EmblemUrl: string;
	Id: number;
	Name: string;
	Owner: { Id: number; Name: string; };
	Roles: { { Name: string; Rank: number; } }
}?)
	return pcall(GroupService.GetGroupInfoAsync, GroupService, groupid)
end

--- returns `pcall(GroupService.PromptJoinAsync, GroupService, groupid)`
function patronage.grouppromptjoin(groupid: number)
	return pcall(GroupService.PromptJoinAsync, GroupService, groupid)
end

--- returns `pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)`
function patronage.policyinfo(player: Player): (boolean, {
	AreAdsAllowed: boolean;
	ArePaidRandomItemsRestricted: boolean;
	AllowedExternalLinkReferences: {string};
	IsContentSharingAllowed: boolean;
	IsEligibleToPurchaseCommerceProduct: boolean;
	IsEligibleToPurchaseSubscription: boolean;
	IsPaidItemTradingAllowed: boolean;
	IsSubjectToChinaPolicies: boolean;
}?)
	assert(IsServer, "patronage.policyinfo can only be called on server")

	return pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
end

--- returns `pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)`
function patronage.regioncode(player: Player)
	assert(IsServer, "patronage.regioncode can only be called on server")
	
	return pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)
end

return patronage