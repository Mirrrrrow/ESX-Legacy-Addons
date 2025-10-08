Config = {
    EarlyRespawnTimer = 60000 * 1,
    BleedoutTimer = 60000 * 10,
    EarlyRespawnFine = false,
    EarlyRespawnFineAmount = 5000,
    DeathAnim = {
        enabled = true,
        dict = 'misslamar1dead_body',
        name = 'dead_idle',
        fadeIn = 10.0,
        fadeOut = 10.0,
        flags = 1|2|8,
        playbackRate = 1.0
    },
    RespawnPoints = {
        { coords = vector3(341.0, -1397.3, 32.5),    heading = 48.5 }, -- Central Los Santos
        { coords = vector3(1836.03, 3670.99, 34.28), heading = 296.06 } -- Sandy Shores
    }
}
