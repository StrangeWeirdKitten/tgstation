/**
 * CO-OP Janitorial Borg Vacuum and Mopping which allows you to clean with a friend.
 * It is intended to be a very powerful cleaning option, as the borg can not use it on its own.
 * Sprites done by nonsense4you.
 */
/obj/item/borg/borg_vacuum
	name = "vacuum apparatus"
	desc = "An operatable vacuum apparatus designed to be used in a co-operative manner"
	icon = 'icons/obj/medical/defib.dmi' // TEMPORARY SPRITES
	icon_state = "defibunit"
	w_class = WEIGHT_CLASS_BULKY
	/// The vacuum hose itself
	var/obj/item/borg_hose/cleaner
	/// The trashbag storage it's connected to
	var/datum/storage/trash = null
	/// Did the borg decide to lock their cleaner?
	var/locked = FALSE
	/// Are we currently active?
	var/on = FALSE

	var/normal_state = "defibunit-paddles"

/**
 * INITIALIZATION CODE
 * Summons a vacuum hose when an apparatus is created
 */

/obj/item/borg/borg_vacuum/Initialize(mapload)
	. = ..()
	cleaner = make_hose()
	update_appearance(UPDATE_OVERLAYS)

/obj/item/borg/borg_vacuum/proc/make_hose()
	return new /obj/item/borg_hose(src)

/**
 * EXAMINE CODE
 * Tell the player if the device is locked and how to offer it to someone.
 */
/obj/item/borg/borg_vacuum/examine(mob/user)
	. = ..()
	. += span_notice("You can <b>Click</b> another player to offer [cleaner]")
	. += span_notice("<b>Alt-Click</b> to <b>[locked ? "Unlock" : "Lock"]</b> [cleaner].")

/**
 * This gives a verb to the janitor borg that allows crew to take its hose
 * This also handles atom interactions with the borg vacuum apparatus
 *
 * dropped() will unlink the trashbag if a non-silicon drops it for debugging / admin usage
 */
/mob/living/silicon/robot/model/janitor/verb/hose_verb()
	set src in view(1)
	set category = "Object"
	set name = "Take Hose"

	var/obj/item/borg/borg_vacuum/vacuum = locate() in src.contents
	if(!iscarbon(usr))
		return NONE
	if(!usr.can_perform_action(src) || !isturf(loc))
		return NONE
	if(!vacuum)
		return NONE
	return vacuum.summon_hose(usr)

/obj/item/borg/borg_vacuum/interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	var/mob/living/target = interacting_with
	if(!iscarbon(target) || !target.stat == CONSCIOUS || !cleaner)
		return ITEM_INTERACT_BLOCKING
	if(on)
		balloon_alert(user, "already deployed!")
	summon_hose(target)
	return ITEM_INTERACT_BLOCKING

/obj/item/borg/borg_vacuum/dropped(mob/user, silent)
	. = ..()
	if(!issilicon(user))
		trash = null

/**
 * DELETION CODE
 * this handles the removal of both apparatus and hose if the item.
 * remove_hose() is required to ensure that the [borg_hose] follows its connected [borg_vacuum] in deletion
 */

/obj/item/borg/borg_vacuum/Destroy()
	if(!cleaner)
		return
	if(on)
		var/M = get(cleaner, /mob)
		remove_hose(M)
	QDEL_NULL(cleaner)
	return ..()

/obj/item/borg/borg_vacuum/proc/remove_hose(mob/user)
	if(ismob(cleaner.loc))
		var/mob/M = cleaner.loc
		M.dropItemToGround(cleaner, TRUE)
	return NONE

/**
 * BASIC OVERLAY CODE
 */

/obj/item/borg/borg_vacuum/update_overlays()
	. = ..()

	if(!on && normal_state)
		. += normal_state

/**
 * HOSE SUMMONING CODE
 * This proc places the physical vacuum hose inside the player's hand.
 */

/obj/item/borg/borg_vacuum/proc/summon_hose(mob/user)
	if(cleaner.loc != cleaner.home)
		to_chat(user, span_warning("[cleaner.loc == user ? "You are already" : "Someone else is"] holding [cleaner.home]'s hose!"))
		return NONE
	if(!in_range(src, user))
		to_chat(user, span_warning("[cleaner]'s hose is overextended and yanks out of your hand!"))
		return NONE
	if(locked)
		to_chat(user, span_warning("[cleaner]'s hose is locked tight!"))
		return NONE
	user.put_in_hands(cleaner)
	update_appearance(UPDATE_OVERLAYS)

/**
 * LOCATE THE TRASHBAG
 * Used by summon_hose to ensure it always tries to find one!
 */

/obj/item/borg/borg_vacuum/proc/locate_trashbag(mob/user)
	var/mob/living/person = user
	if(trash)
		return NONE
	for(var/obj/item/storage/bag/trash/trash_bag in person.contents) // Get the storage datum of the trashbag
		trash = trash_bag.atom_storage
		message_admins("[trash], [trash_bag], [person]")
/**
 * INTERACTION CODE
 * Allows the player to recall the hose and toggle the locks with an alt click
 */

/obj/item/borg/borg_vacuum/attack_self(mob/user, modifiers)
	. = ..()
	if(!cleaner)
		return NONE
	if(on)
		cleaner.return_to_borg()
		return NONE
	if(issilicon(user))
		return NONE
	/// Primarily debug code, but makes the vacuum usable as a stand alone item.
	summon_hose(user)

/obj/item/borg/borg_vacuum/click_alt(mob/user)
	balloon_alert(user, "lock toggled [locked ? "off" : "on"].")
	if(on)
		cleaner.return_to_borg(sound = FALSE)
		locked = TRUE
		return CLICK_ACTION_SUCCESS
	locked = !locked
	playsound(src, 'sound/machines/click.ogg', 30, TRUE)
	return CLICK_ACTION_SUCCESS

/**
 *	VACUUM HOSE ITEM
 *
 *  This is the vacuum cleaner itself that is operated by an organic crewmember.
 */

/obj/item/borg_hose
	name = "vacuum hose"
	desc = "A duel mode vacuum and scrubber attached to your favorite cleaning buddy!"
	icon = 'icons/obj/service/janitor.dmi'
	icon_state = "vacuum"
	inhand_icon_state = "vacuum"
	righthand_file = 'icons/mob/inhands/equipment/custodial_righthand.dmi'
	w_class = WEIGHT_CLASS_BULKY
	/// Cleaning modes - MODE_VACUUM and MODE_MOP
	var/clean_mode = MODE_VACUUM
	/// The apparatus itself.
	var/obj/item/borg/borg_vacuum/home

/**
 * INITIALIZE AND DESTROY
 */
/obj/item/borg_hose/Initialize(mapload)
	. = ..()
	home = loc
	AddComponent( \
		/datum/component/transforming, \
		w_class_on = w_class, \
		clumsy_check = FALSE, \
		inhand_icon_change = FALSE, \
	)
	RegisterSignal(src, COMSIG_TRANSFORMING_ON_TRANSFORM, PROC_REF(on_transform))

/obj/item/borg_hose/Destroy(force)
	home = null
	UnregisterSignal(src, COMSIG_TRANSFORMING_ON_TRANSFORM)
	return ..()

/**
 * EXAMINE INFORMATION
 */
/obj/item/borg_hose/examine(mob/user)
	. = ..()
	if(clean_mode == MODE_VACUUM)
		. += span_notice("The switch is set to <b>VACUUMING</b>.")
	if(clean_mode == MODE_MOP)
		. += span_notice("The switch is set to <b>MOPPING</b>.")

/**
 * MAIN VACUUMING AND CLEANING FUNCTIONALITY
 *
 * on_transform() handles the switch between both modes.
 */

/obj/item/borg_hose/interact_with_atom(obj/thing, mob/living/user, params)
	. = ..()
	var/obj/item/target = thing

	if(!istype(target, /obj/item)) // Only vacuume actual items
		return NONE
	if(clean_mode == MODE_MOP || !home.trash) // Do we have a trashbag and are we vacuuming?
		return NONE
	if(target.anchored || target.w_class >= WEIGHT_CLASS_BULKY)
		return NONE
	for(var/obj/item/I in get_turf(target))
		I.spasm_animation(3)
	addtimer(CALLBACK(src, PROC_REF(vacuum_items), target, user), 0.2 SECONDS)

/obj/item/borg_hose/proc/vacuum_items(obj/thing, mob/living/user)
	home.trash.collection_mode = COLLECT_SAME
	home.trash.collect_on_turf(thing, user)

/obj/item/borg_hose/proc/on_transform(obj/item/source, mob/user, active)
	SIGNAL_HANDLER

	clean_mode = (active ? MODE_MOP : MODE_VACUUM)
	if(!user)
		return COMPONENT_NO_DEFAULT_MESSAGE
	playsound(src, 'sound/weapons/batonextend.ogg', 20, TRUE)
	if(clean_mode == MODE_VACUUM) // Handles the cleaner component. Don't mop if vacuuming
		qdel(GetComponent(/datum/component/cleaner))
	if(clean_mode == MODE_MOP)
		AddComponent( \
			/datum/component/cleaner, \
			base_cleaning_duration = 1 SECONDS, \
		)
	return COMPONENT_NO_DEFAULT_MESSAGE

/**
 * This handles registering unregistering [COMSIG_MOVABLE_MOVED]
 * This also handles returning the hose back to its home
 */

/obj/item/borg_hose/equipped(mob/user, slot)
	. = ..()
	if(!home)
		message_admins("equipped failed to apply")
		return NONE
	home.on = TRUE
	message_admins("signal properly applied for COMSIG_MOVABLE_MOVED")
	RegisterSignal(user, COMSIG_MOVABLE_MOVED, PROC_REF(check_range))

/obj/item/borg_hose/dropped(mob/user, silent = TRUE)
	. = ..()
	if(!home)
		return NONE
	if(user)
		home.on = FALSE
		UnregisterSignal(user, COMSIG_MOVABLE_MOVED)
	to_chat(user, span_notice("The vacuum hose retracts back into [home]"))
	return_to_borg()
	home.update_appearance(UPDATE_OVERLAYS)

/obj/item/borg_hose/proc/return_to_borg(sound = TRUE)
	if(!home)
		return NONE
	if(sound)
		playsound(src, 'sound/machines/click.ogg', 20, FALSE)
	forceMove(home)

/**
 * [COMSIG_MOVABLE_MOVED] Handler to check the range every time Moved() is called
 */

/obj/item/borg_hose/Moved(atom/old_loc, movement_dir, forced, list/old_locs, momentum_change = TRUE)
	. = ..()
	check_range()

/obj/item/borg_hose/proc/check_range()
	SIGNAL_HANDLER

	if(!home)
		return
	if(!IN_GIVEN_RANGE(src, home, 5)) // Allows you to clean everything in the same room
		if(isliving(loc))
			var/mob/living/user = loc
			to_chat(user, span_warning("[home]'s hose extends too much and springs out of your hands!"))
		else
			visible_message(span_notice("[src] snaps back into [home]."))
		return_to_borg()

