import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/rating/data/models/top_30_users_dto.dart';
import 'package:vozhaomuz/core/utils/avatar_url_helper.dart';

class VozhaomuzesInformation extends StatelessWidget {
  final Top30UsersDto user;
  final int index;

  const VozhaomuzesInformation({
    super.key,
    required this.user,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final url = user.avatarUrl;
    final isPremium = user.userType == 'pre';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 15, left: 1),
                child: Text(
                  '${index + 1}',
                  style: AppTextStyles.whiteTextStyle.copyWith(
                    color: Colors.grey,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 53,
                    height: 53,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isPremium
                          ? Border.all(color: Color(0xFFF9A628), width: 2)
                          : null,
                      image: DecorationImage(
                        image: (url != null && url.isNotEmpty)
                            ? NetworkImage(buildAvatarUrl(url))
                            : const AssetImage(
                                    'assets/images/UIHome/usercircle.png',
                                  )
                                  as ImageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  if (isPremium)
                    Positioned(
                      top: -26,
                      right: 10,
                      child: Image.asset(
                        'assets/images/group_2.png',
                        width: 33,
                        height: 33,
                      ),
                    ),
                ],
              ),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name ?? 'unknown'.tr(),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'n_words'.tr(args: ['${user.count ?? 0}']),
                        style: TextStyle(color: Colors.blue),
                      ),
                      if (user.organizationName != null &&
                          user.organizationName!.isNotEmpty) ...[
                        SizedBox(width: 90.sp),
                        Text(
                          '${user.organizationName!}',
                          style: TextStyle(
                            color: const Color.fromRGBO(33, 150, 243, 1),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
