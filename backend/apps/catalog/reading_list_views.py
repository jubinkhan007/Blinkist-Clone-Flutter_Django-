import uuid
from django.db import models, transaction
from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Book, UserReadingList, UserReadingListItem
from .reading_list_serializers import (
    AddBookToReadingListSerializer,
    ReorderReadingListSerializer,
    UserReadingListCreateUpdateSerializer,
    UserReadingListDetailSerializer,
    UserReadingListSummarySerializer,
)


class UserReadingListListView(APIView):
    """
    GET: Returns all reading lists created by the authenticated user.
    POST: Creates a new reading list for the authenticated user.
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        lists = (
            UserReadingList.objects.filter(user=request.user)
            .annotate(
                annotated_items_count=models.Count('items'),
                annotated_total_minutes=models.Sum('items__book__estimated_read_time_minutes'),
            )
            .prefetch_related('items__book', 'items')
            .order_by('-updated_at')
        )

        # Inject computed attributes for serializer
        for lst in lists:
            lst.items_count = lst.annotated_items_count
            lst.total_estimated_minutes = lst.annotated_total_minutes or 0

        serializer = UserReadingListSummarySerializer(
            lists, many=True, context={'request': request}
        )
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = UserReadingListCreateUpdateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_list = serializer.save(user=request.user)

        new_list.items_count = 0
        new_list.total_estimated_minutes = 0

        detail_serializer = UserReadingListDetailSerializer(
            new_list, context={'request': request}
        )
        return Response(detail_serializer.data, status=status.HTTP_201_CREATED)


class UserReadingListDetailView(APIView):
    """
    GET: View list details. Accessible by owner, or by anyone if public / valid share_token.
    PATCH: Update list details (owner only).
    DELETE: Delete list (owner only).
    """
    permission_classes = [permissions.AllowAny]

    def _get_list(self, pk, request):
        lst = get_object_or_404(
            UserReadingList.objects.select_related('user').prefetch_related(
                'items__book__author',
                'items__book__categories',
                'items__book__sections',
                'items__book',
            ),
            pk=pk,
        )
        # Check permissions
        is_owner = request.user.is_authenticated and request.user.id == lst.user_id
        token_arg = request.query_params.get('token')
        has_token = token_arg and str(lst.share_token) == token_arg.strip()

        if not (is_owner or lst.is_public or has_token):
            return None, Response(
                {'error': 'This space is private.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return lst, None

    def get(self, request, pk):
        lst, err_resp = self._get_list(pk, request)
        if err_resp:
            return err_resp

        lst.items_count = lst.items.count()
        lst.total_estimated_minutes = lst.total_estimated_minutes

        serializer = UserReadingListDetailSerializer(lst, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)

    def patch(self, request, pk):
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        lst = get_object_or_404(UserReadingList, pk=pk)
        if lst.user_id != request.user.id:
            return Response(
                {'error': 'Only the owner can edit this space.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = UserReadingListCreateUpdateSerializer(
            lst, data=request.data, partial=True
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()

        lst.items_count = lst.items.count()
        lst.total_estimated_minutes = lst.total_estimated_minutes

        detail_serializer = UserReadingListDetailSerializer(
            lst, context={'request': request}
        )
        return Response(detail_serializer.data, status=status.HTTP_200_OK)

    def delete(self, request, pk):
        if not request.user.is_authenticated:
            return Response(
                {'error': 'Authentication required.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        lst = get_object_or_404(UserReadingList, pk=pk)
        if lst.user_id != request.user.id:
            return Response(
                {'error': 'Only the owner can delete this space.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        lst.delete()
        return Response(
            {'message': 'Space deleted successfully.'},
            status=status.HTTP_204_NO_CONTENT,
        )


class UserReadingListAddBookView(APIView):
    """
    POST: Adds a book to the space. Owner only.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        lst = get_object_or_404(UserReadingList, pk=pk)
        if lst.user_id != request.user.id:
            return Response(
                {'error': 'Only the owner can add books to this space.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = AddBookToReadingListSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        book_slug = serializer.validated_data['book_slug']
        note = serializer.validated_data.get('note', '')

        book = get_object_or_404(Book, slug=book_slug)

        # Append to end of list
        max_order = (
            UserReadingListItem.objects.filter(reading_list=lst).aggregate(
                models.Max('order')
            )['order__max']
            or 0
        )
        item, created = UserReadingListItem.objects.get_or_create(
            reading_list=lst,
            book=book,
            defaults={'order': max_order + 1, 'note': note},
        )
        if not created and note:
            item.note = note
            item.save(update_fields=['note'])

        lst.save(update_fields=['updated_at'])

        return Response(
            {
                'message': f"Added '{book.title}' to {lst.title}.",
                'list_id': lst.id,
                'book_slug': book.slug,
                'items_count': lst.items.count(),
            },
            status=status.HTTP_200_OK,
        )


class UserReadingListRemoveBookView(APIView):
    """
    DELETE: Removes a book from the space. Owner only.
    """
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, pk, book_slug):
        lst = get_object_or_404(UserReadingList, pk=pk)
        if lst.user_id != request.user.id:
            return Response(
                {'error': 'Only the owner can remove books from this space.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        deleted_count, _ = UserReadingListItem.objects.filter(
            reading_list=lst,
            book__slug=book_slug,
        ).delete()

        if deleted_count > 0:
            lst.save(update_fields=['updated_at'])

        return Response(
            {
                'message': 'Book removed from space.',
                'list_id': lst.id,
                'book_slug': book_slug,
                'items_count': lst.items.count(),
            },
            status=status.HTTP_200_OK,
        )


class UserReadingListReorderView(APIView):
    """
    POST: Reorders books in the reading list by given slug list. Owner only.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        lst = get_object_or_404(UserReadingList, pk=pk)
        if lst.user_id != request.user.id:
            return Response(
                {'error': 'Only the owner can reorder this space.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        serializer = ReorderReadingListSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        book_slugs = serializer.validated_data['book_slugs']

        with transaction.atomic():
            for idx, slug in enumerate(book_slugs, start=1):
                UserReadingListItem.objects.filter(
                    reading_list=lst,
                    book__slug=slug,
                ).update(order=idx)
            lst.save(update_fields=['updated_at'])

        return Response(
            {'message': 'Space order updated.', 'list_id': lst.id},
            status=status.HTTP_200_OK,
        )


class UserReadingListMembershipView(APIView):
    """
    GET: Returns IDs of all spaces created by the user that contain the specified book.
    ?book_slug=<slug>
    """
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        book_slug = request.query_params.get('book_slug')
        if not book_slug:
            return Response(
                {'error': 'book_slug parameter is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        list_ids = list(
            UserReadingListItem.objects.filter(
                reading_list__user=request.user,
                book__slug=book_slug,
            ).values_list('reading_list_id', flat=True)
        )

        return Response(
            {'book_slug': book_slug, 'list_ids': list_ids},
            status=status.HTTP_200_OK,
        )


class SharedReadingListDetailView(APIView):
    """
    GET: Resolves a shared reading space by its unique share token.
    """
    permission_classes = [permissions.AllowAny]

    def get(self, request, token):
        lst = get_object_or_404(
            UserReadingList.objects.select_related('user').prefetch_related(
                'items__book__author',
                'items__book__categories',
                'items__book',
            ),
            share_token=token,
        )

        lst.items_count = lst.items.count()
        lst.total_estimated_minutes = lst.total_estimated_minutes

        serializer = UserReadingListDetailSerializer(lst, context={'request': request})
        return Response(serializer.data, status=status.HTTP_200_OK)


class SharedReadingListCloneView(APIView):
    """
    POST: Clones a shared reading space into the authenticated user's account.
    """
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, token):
        source_list = get_object_or_404(
            UserReadingList.objects.prefetch_related('items__book'),
            share_token=token,
        )

        with transaction.atomic():
            cloned_list = UserReadingList.objects.create(
                user=request.user,
                title=f"{source_list.title} (Saved)",
                description=source_list.description,
                emoji=source_list.emoji,
                color_hex=source_list.color_hex,
                is_public=False,
            )

            new_items = []
            for item in source_list.items.all():
                new_items.append(
                    UserReadingListItem(
                        reading_list=cloned_list,
                        book=item.book,
                        order=item.order,
                        note=item.note,
                    )
                )
            UserReadingListItem.objects.bulk_create(new_items)

        cloned_list.items_count = len(new_items)
        cloned_list.total_estimated_minutes = source_list.total_estimated_minutes

        serializer = UserReadingListDetailSerializer(
            cloned_list, context={'request': request}
        )
        return Response(serializer.data, status=status.HTTP_201_CREATED)
