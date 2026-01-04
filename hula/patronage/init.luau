--!strict

local RunService = game:GetService("RunService")
local IsServer = RunService:IsServer()

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

local AvatarEditorService = game:GetService("AvatarEditorService")
local HttpService = game:GetService("HttpService")
local LocalizationService = game:GetService("LocalizationService")
local MarketplaceService = game:GetService("MarketplaceService")
local PolicyService = game:GetService("PolicyService")

--- ### patronage.luau
---
--- player patronage (devproducts, gamepasses, premium, group membership, global lists, etc)
local patronage = {
	regionflag = "h_region"; --- for external use
	policyflag = "h_policyinfo"; --- for external use
}

--- returns `pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, assetid, avataritemtype, shouldfavorite)`
function patronage.promptsetfavorite(assetid: number, avataritemtype: Enum.AvatarItemType, shouldfavorite: boolean)
	return pcall(AvatarEditorService.PromptSetFavorite, AvatarEditorService, assetid, avataritemtype, shouldfavorite)
end

--- returns `AvatarEditorService.PromptSetFavoriteCompleted`
function patronage.promptsetfavoritecompleted()
	return AvatarEditorService.PromptSetFavoriteCompleted
end

--- returns `pcall(a.IsInGroup, a, groupid)`
function patronage.isingroup(a: Player, groupid: number)
	return pcall(a.IsInGroupAsync, a, groupid)
end

--- returns `pcall(a.IsFriendsWith, a, b.UserId)`
function patronage.isfriendswith(a: Player, b: Player)
	return pcall(a.IsFriendsWithAsync, a, b.UserId)
end

--- returns `pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)`
function patronage.region(player: Player)
	assert(IsServer, "patronage.region can only be called on server")

	return pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)
end

--- returns `pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)`
function patronage.policyinfo(player: Player)
	assert(IsServer, "patronage.policyinfo can only be called on server")

	return pcall(PolicyService.GetPolicyInfoForPlayerAsync, PolicyService, player)
end

--- returns value from json-encoded policyinfo
function patronage.policyfromjson(json: string,
	key:  "AreAdsAllowed" --- boolean; immersive ads
		| "ArePaidRandomItemsRestricted" --- boolean; lootboxes
		| "AllowedExternalLinkReferences" --- {string}; external links 
		| "IsContentSharingAllowed" --- boolean; share content off platform
		| "IsEligibleToPurchaseCommerceProduct" --- boolean; off platform commerce products
		| "IsEligibleToPurchaseSubscription" --- boolean; in-game subscriptions
		| "IsPaidItemTradingAllowed" --- boolean; item trading
		| "IsSubjectToChinaPolicies" --- boolean; great mentor, heroic leader
		| string
)
	local decoded = HttpService:JSONDecode(json)

	if type(decoded) == "table" then
		return decoded[key]
	end

	return nil
end

--- returns `pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, itemtype)`
function patronage.getproductinfo(id: number, itemtype: Enum.InfoType)
	return pcall(MarketplaceService.GetProductInfoAsync, MarketplaceService, id, itemtype)
end

--- returns an empty minimum marketplace product
function patronage.minproduct()
	return {
		--- devproduct or gamepass
		type = "devproduct" :: "devproduct"|"gamepass";
		--- devproduct or gamepass id
		id = 0;
	}
end

--- prompts devproduct or gamepass purchase \
--- if called locally, `player` default to the localplayer \
--- returns, depending on product type: \
--- `product.Type == "devproduct"`: `pcall(pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, product.id))` \
--- `product.Type == "gamepass"`: `pcall(pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, product.id))`
function patronage.promptpurchase(product: typeof(patronage.minproduct()) & {[string]: unknown}, player: Player?)
	player = player or LocalPlayer
	assert(player, "patronage.promptpurchase() expected Player, got", typeof(player))

	if product.Type == "devproduct" then
		return pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, player, product.id)
	elseif product.Type == "gamepass" then
		return pcall(MarketplaceService.PromptGamePassPurchase, MarketplaceService, player, product.id)
	else
		error("expected product type devproduct or gamepass, got product type", product.type)
	end
end

--- returns `pcall(MarketplaceService.PromptPremiumPurchase, MarketplaceService, player or LocalPlayer)`
function patronage.promptpremiumpurchase(player: Player?)
	return pcall(MarketplaceService.PromptPremiumPurchase, MarketplaceService, player or LocalPlayer)
end

--- returns empty devproduct purchase receipt info
function patronage.receiptinfo()
	return {
		--- unique purchase id
		PurchaseId = "";
		--- purchaser userid
		PlayerId = 0;
		--- devproduct id
		ProductId = 0;
		--- placeid of purchase
		PlaceIdWherePurchased = 0;
		--- currency spent
		CurrencySpent = 0;
		--- Enum.CurrencyType.Robux
		CurrencyType = Enum.CurrencyType.Robux;
	}
end

--- connects: \
--- `MarketplaceService.ProcessReceipt` -> `productpurchased` \
--- `MarketplaceService.PromptGamePassPurchaseFinished` -> `productpurchased` \
--- `Players.PlayerMembershipChanged` -> `membershipchanged`
function patronage.receipt(productpurchased: (player: Player, product: typeof(patronage.minproduct())) -> boolean, membershipchanged: (player: Player, membershiptype: Enum.MembershipType) -> ())
	assert(IsServer, "patronage.receipt can only be called on server")

	--- devproduct
	MarketplaceService.ProcessReceipt = function(receipt: typeof(patronage.receiptinfo()))
		return productpurchased(Players:GetPlayerByUserId(receipt.PlayerId), { type = "devproduct"; id = receipt.ProductId; })
			and Enum.ProductPurchaseDecision.PurchaseGranted
			or Enum.ProductPurchaseDecision.NotProcessedYet
	end
	--- gamepass
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamepassid: number, purchased: boolean)
		if not purchased then return end

		return productpurchased(player, { type = "gamepass"; id = gamepassid; })
	end)
	--- bc
	Players.PlayerMembershipChanged:Connect(function(player: Player)
		membershipchanged(player, player.MembershipType)
	end)
end

return patronage