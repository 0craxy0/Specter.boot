-- Specter module catalog and metadata registry.
--
-- This Specter file intentionally contains metadata only. Actions are safe
-- placeholders for Specter UI wiring and do not perform gameplay automation or
-- client modification.

export type ActionMetadata = {
	label: string,
	description: string,
	status: "placeholder",
	callbackKey: string,
}

export type ModuleMetadata = {
	id: string,
	name: string,
	description: string,
	category: "Combat" | "Movement" | "Visuals" | "Utility",
	enabled: boolean,
	action: ActionMetadata,
}

export type Category = "Combat" | "Movement" | "Visuals" | "Utility"

local function placeholderAction(moduleId: string): ActionMetadata
	return {
		label = "Configure Specter Module",
		description = "Specter placeholder action; no gameplay behavior is attached.",
		status = "placeholder",
		callbackKey = `specter.catalog.placeholder.{moduleId}`,
	}
end

local function module(
	id: string,
	name: string,
	description: string,
	category: Category,
	enabled: boolean?
): ModuleMetadata
	return {
		id = id,
		name = name,
		description = description,
		category = category,
		enabled = enabled == true,
		action = placeholderAction(id),
	}
end

local Catalog = {
	{
		id = "combat",
		name = "Combat",
		modules = {
			module("combat.targeting", "Specter Targeting Preferences", "Specter metadata placeholder for target-selection preferences.", "Combat"),
			module("combat.training", "Specter Training Tools", "Specter metadata placeholder for non-invasive practice utilities.", "Combat"),
		},
	},
	{
		id = "movement",
		name = "Movement",
		modules = {
			module("movement.presets", "Specter Movement Presets", "Specter metadata placeholder for saved, user-defined movement preferences.", "Movement"),
			module("movement.accessibility", "Specter Accessibility", "Specter metadata placeholder for camera and input accessibility settings.", "Movement"),
		},
	},
	{
		id = "visuals",
		name = "Visuals",
		modules = {
			module("visuals.theme", "Specter Theme", "Specter metadata placeholder for WindUI appearance preferences.", "Visuals", true),
			module("visuals.overlay", "Specter Information Overlay", "Specter metadata placeholder for local, non-invasive status presentation.", "Visuals"),
		},
	},
	{
		id = "utility",
		name = "Utility",
		modules = {
			module("utility.settings", "Specter Settings", "Specter metadata placeholder for configuration management.", "Utility", true),
			module("utility.about", "About Specter Hub", "Displays Specter Hub version and safe-use information.", "Utility", true),
		},
	},
}

return Catalog
