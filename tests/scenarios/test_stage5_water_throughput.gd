extends TestCase


func run() -> Array[String]:
    var manual := Stage5TestFactory.run_water_window(false, 600)
    var piped := Stage5TestFactory.run_water_window(true, 600)
    var ratio := float(piped) / float(maxi(manual, 1))
    print("STAGE5_WATER manual=%d pipe=%d ratio=%.2f" % [manual, piped, ratio])
    assert_true(ratio >= 3.0, "при постоянном спросе труба минимум втрое быстрее ручной подачи")
    return finish()
