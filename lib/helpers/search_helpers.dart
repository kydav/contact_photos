import 'package:contact_photos/helpers/image_logo_helpers.dart';
import 'package:contact_photos/models/company_image_option.dart';
import 'package:flutter/material.dart';

class SearchHelpers {
  Future<void> searchWebsiteImages(
      String? companyName,
      String? companyWebsiteUrl,
      ValueNotifier<String?> errorText,
      ValueNotifier<List<CompanyImageOption>> imageOptions,
      ValueNotifier<bool> isLoading,
      ValueNotifier<bool> hasSearchedWebsite,
      ValueNotifier<bool> hasSearchedLogosWorld,
      ValueNotifier<bool> hasSearchedSocial,
      ValueNotifier<double?> progressValue,
      ValueNotifier<String?> progressLabel) async {
    if (companyName == null || companyWebsiteUrl == null) {
      errorText.value = 'Select a company first to search for images.';
      imageOptions.value = [];
      return;
    }

    isLoading.value = true;
    errorText.value = null;
    imageOptions.value = [];
    hasSearchedWebsite.value = false;
    hasSearchedLogosWorld.value = false;
    hasSearchedSocial.value = false;
    progressValue.value = null;
    progressLabel.value = 'Collecting image candidates from website...';

    try {
      final primaryUrls = await ImageLogoHelpers.queryImageUrlsFromWebsite(
        companyName: companyName,
        websiteUrl: companyWebsiteUrl,
      );

      progressLabel.value =
          'Validating ${primaryUrls.length} candidate images...';
      imageOptions.value = await ImageLogoHelpers.loadRenderableImageOptions(
        primaryUrls,
        onProgress: (completed, total) {
          if (total <= 0) {
            progressValue.value = null;
            progressLabel.value = 'No image candidates to validate.';
            return;
          }
          progressValue.value = completed / total;
          progressLabel.value = 'Checking image $completed of $total...';
        },
      );
      hasSearchedWebsite.value = true;

      if (imageOptions.value.length <= 3) {
        progressValue.value = null;
        progressLabel.value =
            'Auto fallback: collecting additional candidates...';

        final logosWorldUrls =
            await ImageLogoHelpers.queryImageUrlsFromLogosWorld(
          companyName: companyName,
          companyWebsiteUrl: companyWebsiteUrl,
        );
        hasSearchedLogosWorld.value = true;

        if (logosWorldUrls.isNotEmpty) {
          final logosWorldOptions =
              await ImageLogoHelpers.loadRenderableImageOptions(
            logosWorldUrls,
            onProgress: (completed, total) {
              if (total <= 0) return;
              progressValue.value = completed / total;
              progressLabel.value =
                  'Auto fallback: checking additional image $completed of $total...';
            },
          );
          imageOptions.value = ImageLogoHelpers.mergeImageOptions(
            imageOptions.value,
            logosWorldOptions,
          );
        }
      }

      if (imageOptions.value.length <= 3) {
        progressValue.value = null;
        progressLabel.value = 'Auto fallback: collecting more candidates...';

        final socialUrls =
            await ImageLogoHelpers.queryImageUrlsFromSocialProfiles(
          companyName: companyName,
          companyWebsiteUrl: companyWebsiteUrl,
        );
        hasSearchedSocial.value = true;

        if (socialUrls.isNotEmpty) {
          final socialOptions =
              await ImageLogoHelpers.loadRenderableImageOptions(
            socialUrls,
            allowSocialAssetUrls: true,
            onProgress: (completed, total) {
              if (total <= 0) return;
              progressValue.value = completed / total;
              progressLabel.value =
                  'Auto fallback: checking more image $completed of $total...';
            },
          );
          imageOptions.value = ImageLogoHelpers.mergeImageOptions(
            imageOptions.value,
            socialOptions,
          );
        }
      }

      if (imageOptions.value.isEmpty) {
        errorText.value =
            'No renderable images were found from configured search sources.';
        progressLabel.value = 'No images found after all fallback levels.';
      } else {
        progressValue.value = 1;
        progressLabel.value = 'Found ${imageOptions.value.length} image(s).';
      }
    } catch (error) {
      errorText.value = 'Could not search company images: $error';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> searchLogosWorldImages(
      String? companyName,
      String? companyWebsiteUrl,
      ValueNotifier<String?> errorText,
      ValueNotifier<List<CompanyImageOption>> imageOptions,
      ValueNotifier<bool> isLoading,
      ValueNotifier<bool> hasSearchedLogosWorld,
      ValueNotifier<double?> progressValue,
      ValueNotifier<String?> progressLabel) async {
    if (companyName == null || companyWebsiteUrl == null) {
      errorText.value = 'Select a company first to search for images.';
      return;
    }

    isLoading.value = true;
    errorText.value = null;
    progressValue.value = null;
    progressLabel.value = 'Collecting fallback candidates...';

    try {
      final logosWorldUrls =
          await ImageLogoHelpers.queryImageUrlsFromLogosWorld(
        companyName: companyName,
        companyWebsiteUrl: companyWebsiteUrl,
      );

      if (logosWorldUrls.isEmpty) {
        hasSearchedLogosWorld.value = true;
        progressLabel.value = 'No fallback candidates found.';
        return;
      }

      final additionalOptions =
          await ImageLogoHelpers.loadRenderableImageOptions(
        logosWorldUrls,
        onProgress: (completed, total) {
          if (total <= 0) return;
          progressValue.value = completed / total;
          progressLabel.value =
              'Checking fallback image $completed of $total...';
        },
      );

      imageOptions.value = ImageLogoHelpers.mergeImageOptions(
        imageOptions.value,
        additionalOptions,
      );
      hasSearchedLogosWorld.value = true;

      if (additionalOptions.isEmpty) {
        progressLabel.value =
            'No renderable fallback images found. Try deeper fallback.';
      } else {
        progressValue.value = 1;
        progressLabel.value =
            'Added ${additionalOptions.length} fallback image(s).';
      }
    } catch (error) {
      errorText.value = 'Could not run fallback search: $error';
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> searchSocialImages(
      String? companyName,
      String? companyWebsiteUrl,
      ValueNotifier<String?> errorText,
      ValueNotifier<List<CompanyImageOption>> imageOptions,
      ValueNotifier<bool> isLoading,
      ValueNotifier<bool> hasSearchedSocial,
      ValueNotifier<double?> progressValue,
      ValueNotifier<String?> progressLabel) async {
    if (companyName == null || companyWebsiteUrl == null) {
      errorText.value = 'Select a company first to search for images.';
      return;
    }

    isLoading.value = true;
    errorText.value = null;
    progressValue.value = null;
    progressLabel.value = 'Collecting deeper fallback candidates...';

    try {
      final socialUrls =
          await ImageLogoHelpers.queryImageUrlsFromSocialProfiles(
        companyName: companyName,
        companyWebsiteUrl: companyWebsiteUrl,
      );

      if (socialUrls.isEmpty) {
        hasSearchedSocial.value = true;
        progressLabel.value = 'No deeper fallback candidates found.';
        return;
      }

      final socialOptions = await ImageLogoHelpers.loadRenderableImageOptions(
        socialUrls,
        allowSocialAssetUrls: true,
        onProgress: (completed, total) {
          if (total <= 0) return;
          progressValue.value = completed / total;
          progressLabel.value =
              'Checking deeper fallback image $completed of $total...';
        },
      );

      imageOptions.value = ImageLogoHelpers.mergeImageOptions(
        imageOptions.value,
        socialOptions,
      );
      hasSearchedSocial.value = true;

      if (socialOptions.isEmpty) {
        progressLabel.value = 'No renderable deeper fallback images found.';
      } else {
        progressValue.value = 1;
        progressLabel.value =
            'Added ${socialOptions.length} deeper fallback image(s).';
      }
    } catch (error) {
      errorText.value = 'Could not run deeper fallback search: $error';
    } finally {
      isLoading.value = false;
    }
  }
}
