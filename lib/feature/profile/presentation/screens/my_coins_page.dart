import 'package:carousel_slider/carousel_slider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/battle/presentation/screens/battle_page.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/home_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/screens/invite_friend_page.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/price_of_coins_widget.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/coins_provider.dart';
import 'package:vozhaomuz/feature/profile/data/model/coin_item.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/payment_choice_dialog.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

enum getCoinType { buyingWay, etcWay }

final getCoinTypeProvider = NotifierProvider<GetCoinTypeNotifier, getCoinType>(
  GetCoinTypeNotifier.new,
);

class GetCoinTypeNotifier extends Notifier<getCoinType> {
  @override
  getCoinType build() => getCoinType.etcWay;
  void set(getCoinType value) => state = value;
}

class MyCoinsPage extends HookConsumerWidget {
  const MyCoinsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        ref.read(getCoinTypeProvider.notifier).set(getCoinType.etcWay);
      });
      return null;
    }, []);
    final currentCoinType = ref.watch(getCoinTypeProvider);
    final currentIndex = useState(0);
    final profileAsync = ref.watch(getProfileInfoProvider);
    final userCoins = profileAsync.value?.money ?? 0;
    final coinsAsync = ref.watch(coinsListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5FAFF),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 35),
        child: Column(
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  child: Icon(
                    Icons.keyboard_arrow_left_outlined,
                    color: Colors.black,
                    size: 40,
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.2),
                Text(
                  'My_coins'.tr(),
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Container(
                width: double.infinity,
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 35),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'your_coins'.tr(),
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '$userCoins',
                        style: TextStyle(
                          color: Colors.yellow.shade800,
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Container(
                width: double.infinity,
                height: 45,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      spreadRadius: 1,
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      MyButton(
                        padding: EdgeInsets.zero,
                        width: MediaQuery.of(context).size.width * 0.455,
                        height: 40,
                        buttonColor: currentCoinType == getCoinType.buyingWay
                            ? const Color.fromARGB(255, 102, 117, 217)
                            : Colors.white,
                        depth: 0,
                        borderRadius: 50,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(getCoinTypeProvider.notifier)
                              .set(getCoinType.buyingWay);
                        },
                        child: Text(
                          'buy_coins'.tr(),
                          style: TextStyle(
                            color: currentCoinType == getCoinType.buyingWay
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      MyButton(
                        padding: EdgeInsets.zero,
                        width: MediaQuery.of(context).size.width * 0.455,
                        height: 40,
                        buttonColor: currentCoinType == getCoinType.etcWay
                            ? const Color.fromARGB(255, 102, 117, 217)
                            : Colors.white,
                        depth: 0,
                        borderRadius: 50,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          ref
                              .read(getCoinTypeProvider.notifier)
                              .set(getCoinType.etcWay);
                        },
                        child: Text(
                          'more_coins'.tr(),
                          style: TextStyle(
                            color: currentCoinType == getCoinType.etcWay
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (currentCoinType == getCoinType.etcWay)
              Padding(
                padding: const EdgeInsets.only(left: 15, right: 15, top: 40),
                child: Container(
                  width: double.infinity,
                  // 45 % of screen height clamped to a readable minimum —
                  // on an iPhone SE (667 pt) 45 % is ~300 pt, not enough
                  // for the 3 list tiles + divider + button without
                  // truncating. The clamp keeps the card usable on
                  // compact devices (iPhone SE, Galaxy A13, small phones).
                  height: (MediaQuery.of(context).size.height * 0.45)
                      .clamp(340.0, 520.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        spreadRadius: 1,
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 20,
                        ),
                        child: Text(
                          'how_to_get_more_coins'.tr(),
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 25,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          width: double.infinity,
                          height: 1,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: ListTileMenu(
                          'earn_by_learning'.tr(),
                          HomePage(),
                          context,
                        ),
                      ),
                      ListTileMenu(
                        'Invite_a_friend'.tr(),
                        InviteFriendPage(),
                        context,
                      ),
                      ListTileMenu(
                        'play_battle_win'.tr(),
                        BattlePage(),
                        context,
                      ),
                      GestureDetector(
                        onTap: () {
                          ref
                              .read(getCoinTypeProvider.notifier)
                              .set(getCoinType.buyingWay);
                        },
                        child: Padding(
                          padding: const EdgeInsets.only(left: 17, top: 15),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_outlined,
                                color: Colors.blue,
                              ),
                              Gap(15),
                              Text(
                                'buy_coins'.tr(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              buyCoin(currentIndex, coinsAsync),
          ],
        ),
      ),
    );
  }

  Widget buyCoin(
    ValueNotifier<int> currentIndex,
    AsyncValue<List<CoinItem>> coinsAsync,
  ) {
    return coinsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 100),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Center(child: Text('${'error'.tr()}: $err')),
      ),
      data: (coinsList) {
        if (coinsList.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: 100),
            child: Center(child: Text('no_coins_available'.tr())),
          );
        }
        return Padding(
          padding: EdgeInsetsGeometry.only(top: 60),
          child: Column(
            children: [
              CarouselSlider.builder(
                itemCount: coinsList.length,
                itemBuilder: (context, index, realIndex) {
                  final coin = coinsList[index];
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: PriceOfCoinsWidget(
                      coinsCount: coin.count,
                      priceCoins: coin.price,
                      coinId: coin.id,
                      onBuy: () {
                        showCoinPaymentDialog(context, coinId: coin.id);
                      },
                    ),
                  );
                },
                options: CarouselOptions(
                  height: 400,
                  onPageChanged: (index, reason) {
                    currentIndex.value = index;
                  },
                  viewportFraction: 0.83,
                  enlargeFactor: 0.3,
                  enlargeCenterPage: false,
                  autoPlay: false,
                  autoPlayInterval: const Duration(seconds: 10),
                  initialPage: coinsList.length > 2 ? 2 : 0,
                ),
              ),
              Gap(60),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(coinsList.length, (i) {
                  return Padding(
                    padding: const EdgeInsets.all(3.5),
                    child: CircleAvatar(
                      radius: 4,
                      backgroundColor: i == currentIndex.value
                          ? Colors.blue
                          : const Color.fromARGB(255, 178, 218, 245),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  ListTileMenu(String title, Widget page, BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
      child: ListTile(
        leading: Icon(Icons.check_circle_outline_outlined, color: Colors.blue),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.blue,
          ),
        ),
      ),
    );
  }
}
