Config = {}

Config.Debug = false -- true zeigt Debug-Ausgaben in der Server-Konsole, false macht das Script ruhiger.
Config.AutoSetupDatabase = true -- true legt/aktualisiert die Datenbanktabellen beim Resource-Start automatisch.
Config.Version = '1.0' -- Aktuelle Script-Version; wird auch vom Updatechecker angezeigt.

Config.UpdateChecker = {
    Enabled = true, -- true prueft beim Resource-Start und per CFX-Konsolencommand auf Updates.
    Url = 'https://api.github.com/repos/PlanktonTVT/ptv_cityhall/releases/latest', -- GitHub-API-URL zur neusten Release-Version.
    DownloadUrl = 'https://github.com/PlanktonTVT/ptv_cityhall/releases/latest', -- Fallback-Download-Link, falls die Update-Datei keinen Link mitliefert.
    Command = 'ptv_cityhall_updatecheck', -- CFX-Konsolencommand fuer einen manuellen Updatecheck.
    PrintIfNoUrl = true -- true schreibt in die Konsole, wenn noch keine Update-URL eingetragen ist.
}

Config.AdminGroups = {
    admin = true -- Gruppe aus der Datenbank users.group, die Adminrechte im Script bekommt.
    -- superadmin = true, -- Weitere erlaubte Admin-Gruppe aus users.group.
    -- owner = true -- Weitere erlaubte Admin-Gruppe aus users.group.
}

Config.Commands = {
    Menu = 'buergermeister', -- Command fuer das normale Rathaus-/Bürgermeister-Menue.
    Market = 'markthalle', -- Command fuer das Markthallenfenster.
    MarketAdmin = 'markthalle_admin', -- Command fuer die Admin-Preisverwaltung der Markthalle.
    Admin = 'bm_admin' -- Admin-Command fuer Wahlen, Steuern, Treasury und Adminfenster.
}

Config.Keys = {
    Interact = 0x760A9C6F -- Taste G zum Oeffnen am Rathaus-/Markthallen-NPC.
}

Config.DefaultTown = 'blackwater' -- Fallback-Stadt, wenn kein Stadtpunkt erkannt wurde oder die Konsole einen Command nutzt.

Config.Town = {
    Name = 'Blackwater', -- Fallback-Stadtname, falls Config.Towns leer ist.
    DefaultTaxRate = 8.0, -- Alter/globaler Standardsteuersatz als Fallback.
    DefaultBuyTaxRate = 8.0, -- Standard-Einkaufsteuer in Prozent fuer neue Staedte/Kategorien.
    DefaultSellTaxRate = 9.0, -- Standard-Verkaufsteuer in Prozent fuer neue Staedte/Kategorien.
    MinTaxRate = 5.0, -- Kleinster erlaubter Steuersatz in Prozent.
    MinSellTaxSpread = 1.0, -- Verkaufsteuer muss mindestens so viele Prozentpunkte hoeher als Einkaufsteuer sein.
    MaxTaxRate = 25.0, -- Groesster erlaubter Steuersatz in Prozent.
    TermDays = 14, -- Amtszeit eines gewaehlten Bürgermeisters in Tagen.
    MarketHall = {
        coords = { x = -839.26, y = -1348.86, z = 44.20 }, -- Fallback-Position fuer Rathaus/Markthalle.
        interactionDistance = 2.25, -- Entfernung, ab der Spieler mit G interagieren koennen.
        hintDistance = 12.0, -- Entfernung, ab der die Naehe-Pruefung und Anzeige aktiv wird.
        Ped = {
            enabled = true, -- true spawnt einen NPC am Punkt, false deaktiviert den NPC.
            model = 'U_M_M_NbxGeneralStoreOwner_01', -- Ped-Modell fuer den NPC.
            coords = { x = -839.26, y = -1348.86, z = 44.20, h = 85.86 } -- Position des NPCs.
        }
    }
}

Config.TownOrder = {
    'blackwater', -- Reihenfolge der Stadtpunkte im Client und beim Setup.
    'valentine', -- Reihenfolge der Stadtpunkte im Client und beim Setup.
    'rhodes', -- Reihenfolge der Stadtpunkte im Client und beim Setup.
    'saintdenis', -- Reihenfolge der Stadtpunkte im Client und beim Setup.
    'strawberry', -- Reihenfolge der Stadtpunkte im Client und beim Setup.
    'armadillo', -- Reihenfolge der Stadtpunkte im Client und beim Setup.
    'tumbleweed', -- Reihenfolge der Stadtpunkte im Client und beim Setup.
    'annesburg', -- Reihenfolge der Stadtpunkte im Client und beim Setup.
    'vanhorn' -- Reihenfolge der Stadtpunkte im Client und beim Setup.
}

Config.CityHallBlip = {
    enabled = true, -- Globaler Schalter fuer Rathaus-Blips; einzelne Staedte koennen darunter trotzdem deaktiviert werden.
    sprite = 1865251988, -- Fallback-Blip-Sprite als numerischer RedM-Hash; sicherer als ein Textname.
    style = 1664425300, -- RedM-Blip-Style fuer Kartenpunkte.
    scale = 0.22, -- Fallback-Groesse, falls eine Stadt keine eigene Blip-Groesse setzt.
    labelPrefix = 'Rathaus' -- Fallback-Text vor dem Stadtnamen, falls eine Stadt kein eigenes Label setzt.
}

Config.Towns = {
    blackwater = {
        Name = 'Blackwater',
        Blip = {
            enabled = true,
            coords = { x = -839.26, y = -1348.86, z = 44.20 },
            sprite = 1865251988,
            style = 1664425300,
            scale = 0.22,
            label = 'Rathaus Blackwater'
        },
        MayorJobs = {
            Enabled = true,
            Jobs = {
                { label = 'Blackwater Town Sheriff', job = 'policebw', grade = 0, jobLabel = 'Blackwater Town Sheriff' },
                { label = 'Blackwater Deputy', job = 'policebw', grade = 3, jobLabel = 'Blackwater Deputy' },
                { label = 'Blackwater Chefarzt', job = 'doctorbw', grade = 0, jobLabel = 'Blackwater Chefarzt' },
                { label = 'Blackwater Pfleger', job = 'doctorbw', grade = 3, jobLabel = 'Blackwater Pfleger' },
                { label = 'Schmarotzer', job = 'unemployed', grade = 0, jobLabel = 'Schmarotzer' }
            }
        },
        MarketHall = {
            coords = { x = -839.26, y = -1348.86, z = 44.20 },
            interactionDistance = 2.25,
            hintDistance = 12.0,
            Ped = {
                enabled = true,
                model = 'u_m_m_bht_blackwaterhunt',
                coords = { x = -839.26, y = -1348.86, z = 44.20, h = 85.86 }
            }
        }
    },
    valentine = {
        Name = 'Valentine',
        Blip = {
            enabled = true,
            coords = { x = -255.47, y = 741.52, z = 118.17 },
            sprite = 1865251988,
            style = 1664425300,
            scale = 0.22,
            label = 'Rathaus Valentine'
        },
        MayorJobs = {
            Enabled = true,
            Jobs = {
                { label = 'Valentine Town Sheriff', job = 'police', grade = 0, jobLabel = 'Valentine Town Sheriff' },
                { label = 'Valentine Deputy', job = 'police', grade = 3, jobLabel = 'Valentine Deputy' },
                { label = 'Valentine Chefarzt', job = 'doctor', grade = 0, jobLabel = 'Valentine Chefarzt' },
                { label = 'Valentine Pfleger', job = 'doctor', grade = 3, jobLabel = 'Valentine Pfleger' },
                { label = 'Schmarotzer', job = 'unemployed', grade = 0, jobLabel = 'Schmarotzer' }
            }
        },
        MarketHall = {
            coords = { x = -255.47, y = 741.52, z = 118.17 },
            interactionDistance = 2.25,
            hintDistance = 12.0,
            Ped = {
                enabled = true,
                model = 'MP_CHU_KID_VALENTINE_MALES_01',
                coords = { x = -255.47, y = 741.52, z = 118.17, h = 286.05 }
            }
        }
    },
    rhodes = {
        Name = 'Rhodes',
        Blip = {
            enabled = true,
            coords = { x = 1348.30, y = -1323.35, z = 77.79 },
            sprite = 1865251988,
            style = 1664425300,
            scale = 0.22,
            label = 'Rathaus Rhodes'
        },
        MayorJobs = {
            Enabled = true,
            Jobs = {
                { label = 'Rhodes Town Sheriff', job = 'policerh', grade = 0, jobLabel = 'Rhodes Town Sheriff' },
                { label = 'Rhodes Deputy', job = 'policerh', grade = 3, jobLabel = 'Rhodes Deputy' },
                { label = 'Rhodes Chefarzt', job = 'doctorrh', grade = 0, jobLabel = 'Rhodes Chefarzt' },
                { label = 'Rhodes Pfleger', job = 'doctorrh', grade = 3, jobLabel = 'Rhodes Pfleger' },
                { label = 'Schmarotzer', job = 'unemployed', grade = 0, jobLabel = 'Schmarotzer' }
            }
        },
        MarketHall = {
            coords = { x = 1348.30, y = -1323.35, z = 77.79 },
            interactionDistance = 2.25,
            hintDistance = 12.0,
            Ped = {
                enabled = true,
                model = 'MP_CHU_ROB_RHODES_MALES_01',
                coords = { x = 1348.30, y = -1323.35, z = 77.79, h = 350.45 }
            }
        }
    },
    saintdenis = {
        Name = 'Saint Denis',
        Blip = {
            enabled = true,
            coords = { x = 2597.91, y = -1299.32, z = 52.82 },
            sprite = 1865251988,
            style = 1664425300,
            scale = 0.22,
            label = 'Rathaus Saint Denis'
        },
        MayorJobs = {
            Enabled = true,
            Jobs = {
                { label = 'Saint Denis Town Sheriff', job = 'policesd', grade = 0, jobLabel = 'Saint Denis Town Sheriff' },
                { label = 'Saint Denis Deputy', job = 'policesd', grade = 3, jobLabel = 'Saint Denis Deputy' },
                { label = 'Saint Denis Chefarzt', job = 'doctorsd', grade = 0, jobLabel = 'Saint Denis Chefarzt' },
                { label = 'Saint Denis Pfleger', job = 'doctorsd', grade = 3, jobLabel = 'Saint Denis Pfleger' },
                { label = 'Schmarotzer', job = 'unemployed', grade = 0, jobLabel = 'Schmarotzer' }
            }
        },
        MarketHall = {
            coords = { x = 2597.91, y = -1299.32, z = 52.82 },
            interactionDistance = 2.25,
            hintDistance = 12.0,
            Ped = {
                enabled = true,
                model = 'msp_saintdenis1_males_01',
                coords = { x = 2597.91, y = -1299.32, z = 52.82, h = 293.82 }
            }
        }
    },
    strawberry = {
        Name = 'Strawberry',
        Blip = {
            enabled = true,
            coords = { x = -1837.52, y = -418.62, z = 161.63 },
            sprite = 1865251988,
            style = 1664425300,
            scale = 0.22,
            label = 'Rathaus Strawberry'
        },
        MayorJobs = {
            Enabled = true,
            Jobs = {
                { label = 'Strawberry Town Sheriff', job = 'policesb', grade = 0, jobLabel = 'Strawberry Town Sheriff' },
                { label = 'Strawberry Deputy', job = 'policesb', grade = 3, jobLabel = 'Strawberry Deputy' },
                { label = 'Strawberry Chefarzt', job = 'doctorsb', grade = 0, jobLabel = 'Strawberry Chefarzt' },
                { label = 'Strawberry Pfleger', job = 'doctorsb', grade = 3, jobLabel = 'Strawberry Pfleger' },
                { label = 'Schmarotzer', job = 'unemployed', grade = 0, jobLabel = 'Schmarotzer' }
            }
        },
        MarketHall = {
            coords = { x = -1837.52, y = -418.62, z = 161.63 },
            interactionDistance = 2.25,
            hintDistance = 12.0,
            Ped = {
                enabled = true,
                model = 'cs_strawberryoutlaw_02',
                coords = { x = -1837.52, y = -418.62, z = 161.63, h = 234.90 }
            }
        }
    },
    armadillo = {
        Name = 'Armadillo',
        Blip = {
            enabled = true,
            coords = { x = -3704.05, y = -2623.63, z = -13.24, h = 49.61 },
            sprite = 1865251988,
            style = 1664425300,
            scale = 0.22,
            label = 'Rathaus Armadillo'
        },
        MayorJobs = {
            Enabled = true,
            Jobs = {
                { label = 'Armadillo Town Sheriff', job = 'policearm', grade = 0, jobLabel = 'Armadillo Town Sheriff' },
                { label = 'Armadillo Deputy', job = 'policearm', grade = 3, jobLabel = 'Armadillo Deputy' },
                { label = 'Armadillo Chefarzt', job = 'doctorarm', grade = 0, jobLabel = 'Armadillo Chefarzt' },
                { label = 'Armadillo Pfleger', job = 'doctorarm', grade = 3, jobLabel = 'Armadillo Pfleger' },
                { label = 'Schmarotzer', job = 'unemployed', grade = 0, jobLabel = 'Schmarotzer' }
            }
        },
        MarketHall = {
            coords = { x = -3704.05, y = -2623.63, z = -13.24 },
            interactionDistance = 2.25,
            hintDistance = 12.0,
            Ped = {
                enabled = true,
                model = 'MP_CHU_KID_ARMADILLO_MALES_01',
                coords = { x = -3704.05, y = -2623.63, z = -13.24, h = 49.61 }
            }
        }
    },
    tumbleweed = {
        Name = 'Tumbleweed',
        Blip = {
            enabled = true,
            coords = { x = -5500.13, y = -2958.90, z = -0.68 },
            sprite = 1865251988,
            style = 1664425300,
            scale = 0.22,
            label = 'Rathaus Tumbleweed'
        },
        MayorJobs = {
            Enabled = true,
            Jobs = {
                { label = 'Tumbleweed Town Sheriff', job = 'policetw', grade = 0, jobLabel = 'Tumbleweed Town Sheriff' },
                { label = 'Tumbleweed Deputy', job = 'policetw', grade = 3, jobLabel = 'Tumbleweed Deputy' },
                { label = 'Tumbleweed Chefarzt', job = 'doctortw', grade = 0, jobLabel = 'Tumbleweed Chefarzt' },
                { label = 'Tumbleweed Pfleger', job = 'doctortw', grade = 3, jobLabel = 'Tumbleweed Pfleger' },
                { label = 'Schmarotzer', job = 'unemployed', grade = 0, jobLabel = 'Schmarotzer' }
            }
        },
        MarketHall = {
            coords = { x = -5500.13, y = -2958.90, z = -0.68 },
            interactionDistance = 2.25,
            hintDistance = 12.0,
            Ped = {
                enabled = true,
                model = 'u_m_m_story_tumbleweed_01',
                coords = { x = -5500.13, y = -2958.90, z = -0.68, h = 16.61 }
            }
        }
    },
    annesburg = {
        Name = 'Annesburg',
        Blip = {
            enabled = true,
            coords = { x = 2951.41, y = 1352.66, z = 44.87 },
            sprite = 1865251988,
            style = 1664425300,
            scale = 0.22,
            label = 'Rathaus Annesburg'
        },
        MayorJobs = {
            Enabled = true,
            Jobs = {
                { label = 'Annesburg Town Sheriff', job = 'policean', grade = 0, jobLabel = 'Annesburg Town Sheriff' },
                { label = 'Annesburg Deputy', job = 'policean', grade = 3, jobLabel = 'Annesburg Deputy' },
                { label = 'Annesburg Chefarzt', job = 'doctoran', grade = 0, jobLabel = 'Annesburg Chefarzt' },
                { label = 'Annesburg Pfleger', job = 'doctoran', grade = 3, jobLabel = 'Annesburg Pfleger' },
                { label = 'Schmarotzer', job = 'unemployed', grade = 0, jobLabel = 'Schmarotzer' }
            }
        },
        MarketHall = {
            coords = { x = 2951.41, y = 1352.66, z = 44.87 },
            interactionDistance = 2.25,
            hintDistance = 12.0,
            Ped = {
                enabled = true,
                model = 'MP_CHU_ROB_ANNESBURG_MALES_01',
                coords = { x = 2951.41, y = 1352.66, z = 44.87, h = 65.61 }
            }
        }
    },
    vanhorn = {
        Name = 'Van Horn',
        Blip = {
            enabled = true,
            coords = { x = 2953.70, y = 508.24, z = 45.88 },
            sprite = 1865251988,
            style = 1664425300,
            scale = 0.22,
            label = 'Rathaus Van Horn'
        },
        MayorJobs = {
            Enabled = true,
            Jobs = {
                { label = 'Van Horn Town Sheriff', job = 'policevh', grade = 0, jobLabel = 'Van Horn Town Sheriff' },
                { label = 'Van Horn Deputy', job = 'policevh', grade = 3, jobLabel = 'Van Horn Deputy' },
                { label = 'Van Horn Chefarzt', job = 'doctorvh', grade = 0, jobLabel = 'Van Horn Chefarzt' },
                { label = 'Van Horn Pfleger', job = 'doctorvh', grade = 3, jobLabel = 'Van Horn Pfleger' },
                { label = 'Schmarotzer', job = 'unemployed', grade = 0, jobLabel = 'Schmarotzer' }
            }
        },
        MarketHall = {
            coords = { x = 2953.70, y = 508.24, z = 45.88 },
            interactionDistance = 2.25,
            hintDistance = 12.0,
            Ped = {
                enabled = true,
                model = 'MP_DE_U_M_M_VANHORN_01',
                coords = { x = 2953.70, y = 508.24, z = 45.88, h = 280.10 }
            }
        }
    }
}

Config.Election = {
    NominationHours = 24, -- Dauer der Kandidaturphase in Stunden.
    VotingHours = 24, -- Dauer der Abstimmphase in Stunden nach der Kandidaturphase.
    MinCandidates = 1, -- Mindestanzahl Kandidaten, damit eine Wahl gueltig ausgewertet wird.
    TieKeepsCurrentMayor = true, -- true bedeutet bei Gleichstand bleibt der aktuelle Bürgermeister im Amt.
    AllowSelfVote = true -- true erlaubt Kandidaten, fuer sich selbst zu stimmen.
}

Config.ElectionReminder = {
    Enabled = true, -- true sendet Wahlhinweise an aktive Bürger der jeweiligen Stadt.
    IntervalMinutes = 20, -- Abstand der Wahlhinweise in Minuten.
    NotifyOnStart = true -- true sendet direkt beim Wahlstart den ersten Hinweis.
}

Config.Citizenship = {
    RequireApprovedForVoting = false, -- true erlaubt nur bestaetigten Bürgern das Abstimmen.
    RequireApprovedForCandidacy = false, -- true erlaubt nur bestaetigten Bürgern die Kandidatur.
    AllowReapplyAfterRemoval = true, -- true erlaubt erneute Bürgerantraege nach Entfernung.
    MaxRegistryRows = 150 -- Maximale Anzahl sichtbarer Eintraege im Bürgerregister.
}

Config.MayorJobs = {
    Enabled = true, -- true erlaubt Bürgermeistern/Admins, Bürgern Jobs zuzuweisen.
    Jobs = {
        { label = 'Schmarotzer', job = 'unemployed', grade = 0, jobLabel = 'Schmarotzer' }
    }
}

Config.Discord = {
    Enabled = true, -- true aktiviert Discord-Webhooks, false deaktiviert sie komplett.
    Webhook = 'DEIN WEBHOOK', -- Discord-Webhook-URL.
    Username = 'PTV Cityhall', -- Name, unter dem der Webhook in Discord postet.
    AvatarUrl = '', -- Optionales Avatarbild fuer den Webhook, leer lassen fuer Standard.
    Color = 16768851, -- Embed-Farbe als Dezimalwert.
    Events = {
        electionStart = true, -- Meldung, wenn eine Wahl startet.
        electionResult = true, -- Meldung, wenn eine Wahl beendet/ausgewertet wird.
        citizenApply = true, -- Meldung, wenn ein Bürgerantrag gestellt wird.
        citizenApproved = true, -- Meldung, wenn ein Bürger bestaetigt wird.
        citizenRemoved = true, -- Meldung, wenn ein Bürger entfernt wird.
        citizenJob = true, -- Meldung, wenn ein Job vergeben wird.
        taxChange = true, -- Meldung, wenn Steuern geaendert werden.
        treasuryGrant = true, -- Meldung, wenn Geld aus der Stadtkasse ausgezahlt wird.
        marketExport = true, -- Meldung, wenn Lagerbestand exportiert und der Stadtkasse gutgeschrieben wird.
        marketWithdraw = true, -- Meldung, wenn Bürgermeister/Admins Waren oder Waffen aus dem Lager entnehmen.
        marketToggle = true -- Meldung, wenn Waren oder Waffen fuer eine Stadt aktiviert/deaktiviert werden.
    }
}

Config.Market = {
    UseConfigPrices = true, -- true setzt die buyPrice/sellPrice aus dieser Config bei jedem Start und Oeffnen in allen Markthallen durch.
    ListingFee = 1.0, -- Gebuehr fuer Spielerangebote in der Markthalle.
    MaxListingsPerPlayer = 20, -- Maximale aktive Spielerangebote pro Charakter.
    MinPrice = 0.01, -- Globaler Mindestpreis, falls Item keinen eigenen minPrice hat.
    MaxPrice = 10000.0, -- Globaler Hoechstpreis, falls Item keinen eigenen maxPrice hat.
    MinAmount = 1, -- Globale Mindestmenge, falls Item keine eigene minAmount hat.
    MaxAmount = 100, -- Globale Hoechstmenge, falls Item keine eigene maxAmount hat.
    MaxActiveListings = 100, -- Maximale Anzahl aktiver Angebote, die angezeigt werden.
    ExportPercent = 5.0, -- Prozent vom Gesamtwert, den die Stadt beim Export von Lagerbestand in die Stadtkasse bekommt.
    AllowSelfPurchase = false, -- true erlaubt Spielern, eigene Angebote zu kaufen.
    MayorNoListingFee = true, -- true befreit Bürgermeister/Admins von der Einstellgebuehr.
    MayorCanRemoveListings = true, -- true erlaubt Bürgermeistern/Admins, Angebote zu entfernen.
    RestrictedItems = {
        money = true, -- Dieses Item darf nicht in der Markthalle eingestellt werden.
        gold = true -- Dieses Item darf nicht in der Markthalle eingestellt werden.
    },
    CategoryOrder = { 'goods', 'weapons' }, -- Reihenfolge der Reiter in der Markthalle.
    CategoryTaxes = {
        goods = {
            buyRate = 5.0, -- Standard-Einkaufsteuer fuer den Reiter Waren.
            sellRate = 7.0 -- Standard-Verkaufsteuer fuer den Reiter Waren.
        },
        weapons = {
            buyRate = 10.0, -- Standard-Einkaufsteuer fuer den Reiter Waffen.
            sellRate = 12.0 -- Standard-Verkaufsteuer fuer den Reiter Waffen.
        }
    },
    Categories = {
        goods = {
            label = 'Waren', -- Anzeigename des Markthallen-Reiters.
            items = {
                bread = {
                    label = 'Brot',
                    minAmount = 1,
                    maxAmount = 25,
                    minPrice = 0.10,
                    maxPrice = 25.00,
                    buyPrice = 2.00,
                    sellPrice = 1.00,
                    initialStock = 0
                },
                water = {
                    label = 'Wasser',
                    minAmount = 1,
                    maxAmount = 25,
                    minPrice = 0.10,
                    maxPrice = 25.00,
                    buyPrice = 2.00,
                    sellPrice = 1.00,
                    initialStock = 0
                }
            }
        },
        weapons = {
            label = 'Waffen', -- Anzeigename des Markthallen-Reiters.
            items = {
                WEAPON_REVOLVER_CATTLEMAN = {
                    label = 'Cattleman Revolver',
                    minAmount = 1,
                    maxAmount = 1,
                    minPrice = 25.00,
                    maxPrice = 1000.00,
                    buyPrice = 50.00,
                    sellPrice = 25.00,
                    initialStock = 0
                },
                WEAPON_REPEATER_CARBINE = {
                    label = 'Carbine Repeater',
                    minAmount = 1,
                    maxAmount = 1,
                    minPrice = 25.00,
                    maxPrice = 1500.00,
                    buyPrice = 350.00,
                    sellPrice = 150.00,
                    initialStock = 0
                }
            }
        }
    }
}

Config.Text = {
    OpenHint = 'G - Markthalle/Rathaus öffnen', -- Text im Interaktionshinweis.
    NoPermission = 'Dafür hast du keine Berechtigung.', -- Meldung bei fehlender Berechtigung.
    InternalError = 'Ein interner Fehler ist aufgetreten.' -- Allgemeine Fehlermeldung bei Serverfehlern.
}
